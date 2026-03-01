{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NoImplicitPrelude #-}

-- |
-- Module      : Main
-- Description : generic tar-map utility (Parallel)
-- Copyright   : (c) Yui Nishimura, 2024
-- License     : MIT
--
-- The "Silver Bullet" Abstraction (Concurrent):
--   tar-map :: (File -> IO [File]) -> TarStream -> TarStream
--
-- Features:
--   - Arbitrary Shell Command Mapping
--   - Parallel Execution (--jobs)
--   - Independent Sandboxing
--   - Stream Processing (Constant Memory for Stream, O(N) threads)
module Main where

import Codec.Archive.Tar qualified as Tar
import Codec.Archive.Tar.Entry qualified as Tar
import Control.Concurrent (getNumCapabilities, myThreadId, setNumCapabilities)
import Control.Concurrent.Async (async, forConcurrently, mapConcurrently, wait)
import Control.Concurrent.MVar (MVar, newMVar, withMVar)
import Control.Concurrent.QSem qualified as QSem
import Control.Concurrent.STM (TChan, TVar, atomically, check, modifyTVar, newTChanIO, newTVarIO, readTChan, readTVar, writeTChan)
import Control.Exception.Safe (bracket, throwString, tryAny)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BL
import Data.Text qualified as T
import Data.Time (UTCTime (..), diffUTCTime, getCurrentTime)
import Data.Time.Calendar (Day (..))
import GHC.Conc (numCapabilities)
import Options.Applicative
import Protolude hiding (async, bracket, cancel, catch, try, wait)
import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist, getTemporaryDirectory, listDirectory, removeDirectoryRecursive)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO (BufferMode (..), Handle, hClose, hFlush, hSetBinaryMode, hSetBuffering)
import System.Process (CreateProcess (..), ProcessHandle, StdStream (..), createProcess, proc, std_err, std_in, std_out, waitForProcess, withCreateProcess)
import System.Timeout (timeout)

-- | Configuration
data Config = Config
  { cmdTemplate :: [[Char]],
    keepOriginal :: Bool,
    stdioMode :: Bool,
    jobs :: Int,
    timeoutSec :: Int
  }

-- | CLI Parser
configParser :: Parser Config
configParser =
  Config
    <$> many (strArgument (metavar "COMMAND_AND_ARGS..."))
    <*> switch (long "keep-structure" <> help "Maintain original directory structure for output files")
    <*> switch (long "stdio" <> help "Pipe entry content via stdin/stdout instead of filesystem sandbox")
    <*> option
      auto
      ( long "jobs"
          <> short 'j'
          <> metavar "N"
          <> help "Number of parallel jobs"
          <> value 4
      )
    <*> option
      auto
      ( long "timeout"
          <> metavar "SECONDS"
          <> help "Timeout per file in seconds"
          <> value 180
      )

-- | Main
main :: IO ()
main = do
  hSetBinaryMode stdin True
  hSetBinaryMode stdout True
  hSetBuffering stdout NoBuffering

  config <- execParser opts

  -- Set capabilities (threads)
  -- In Haskell, default is -N (all cores) if compiled threaded, but we can't control RTS flags easily in script.
  -- But 'async' uses lightweight threads so it's fine.

  content <- BL.hGetContents stdin
  let entries = Tar.read content

  processEntriesParallel config entries
  where
    opts =
      info
        (configParser <**> helper)
        ( fullDesc
            <> progDesc "Apply a command to each file in a tar stream, emitting resulting files"
            <> header "tar-map - The Monadic Bind for Filesystem Streams (Parallel)"
        )

-- | Parallel Processing Logic
-- Strategy:
--  1. Main thread iterates input Tar entries.
--  2. "Standard Files" are dispatched to a worker pool (or semaphore controlled async).
--  3. "Other Entries" (Dirs, Links) are passed through (?) or ignored?
--       Typically `tar-map` should map file content. Directories are implicit in tar usually.
--       Let's ignore directories for processing but maybe pass them through if we were a true filter?
--       Current logic: Only process NormalFile. Drop others?
--       Ideally: Pass through non-files directly to stdout. Process files.
--       But this causes out-of-order output if we are not careful.
--       Simple version: Only emit PROCESSED files. (Filter style).
--       Input dirs are ignored. Output dirs are synthesized by `Tar.pack` or file paths.
processEntriesParallel :: Config -> Tar.Entries Tar.FormatError -> IO ()
processEntriesParallel config entries = do
  -- Output Lock (Stdout is not thread safe for interleaved byte writes)
  outLock <- newMVar ()

  -- Semaphore for parallelism
  sem <- QSem.newQSem (jobs config)

  -- Active job counter for waiting completion
  active <- newTVarIO (0 :: Int)

  let loop Tar.Done = return ()
      loop (Tar.Fail e) = withMVar outLock $ \_ -> logInfo $ "[tar-map] Tar Error: " <> T.pack (show e :: [Char])
      loop (Tar.Next entry next) = do
        case Tar.entryContent entry of
          Tar.NormalFile _ _ -> do
            -- Wait for slot
            QSem.waitQSem sem
            atomically $ modifyTVar active (+ 1)

            -- Fork worker with guaranteed cleanup
            _ <- async $ flip finally (do QSem.signalQSem sem; atomically $ modifyTVar active (subtract 1)) $ do
              let processEntry = if stdioMode config then processStdioEntry else processSingleEntry
              result <- tryAny $ processEntry config entry

              withMVar outLock $ \_ ->
                case result of
                  Right newEntries -> do
                    logInfo $ "Done: " <> T.pack (Tar.entryPath entry)
                    writeStrippingEOA stdout (Tar.write newEntries)
                  Left e ->
                    logInfo $ "Error: " <> T.pack (Tar.entryPath entry) <> ": " <> show e

            loop next
          _ -> loop next

  loop entries

  -- Wait for all workers to finish
  atomically $ do
    n <- readTVar active
    check (n == 0)

  -- Write final EOA (two 512-byte blocks of zeros)
  BL.hPut stdout (BL.replicate 1024 0)

-- | Stdio mode: pipe entry content through command stdin/stdout.
-- Preserves tar path (1:1 Functor semantics — no filesystem sandbox).
processStdioEntry :: Config -> Tar.Entry -> IO [Tar.Entry]
processStdioEntry config entry = do
  let path = Tar.entryPath entry
      content = case Tar.entryContent entry of
        Tar.NormalFile c _ -> c
        _ -> BL.empty
      (cmd : args) = case cmdTemplate config of
        [] -> ["cat"]
        xs -> xs

  let cp = (proc cmd args)
        { std_in = CreatePipe
        , std_out = CreatePipe
        , std_err = Inherit
        }

  result <- timeout (timeoutSec config * 1000000) $
    withCreateProcess cp $ \(Just stdinH) (Just stdoutH) _ ph -> do
      -- Async writer to prevent deadlock on full pipe buffer
      writer <- async $ BL.hPut stdinH content >> hClose stdinH
      -- Strict read to force consumption before handle cleanup
      output <- BL.fromStrict <$> BS.hGetContents stdoutH
      wait writer
      exitCode <- waitForProcess ph
      case exitCode of
        ExitSuccess -> return output
        ExitFailure n -> throwString $ "Command exited with code " <> show n

  case result of
    Nothing -> throwString "Timeout"
    Just output ->
      case Tar.toTarPath False path of
        Right tp -> return [Tar.fileEntry tp output]
        Left e -> throwString $ "Invalid tar path: " <> e

processSingleEntry :: Config -> Tar.Entry -> IO [Tar.Entry]
processSingleEntry config entry = do
  let path = Tar.entryPath entry
      content = case Tar.entryContent entry of
        Tar.NormalFile c _ -> c
        _ -> BL.empty

  withSystemTempDirectory "tm" $ \tmpDir -> do
    let workPath = tmpDir </> path
    createDirectoryIfMissing True (takeDirectory workPath)
    BL.writeFile workPath content

    let dir = takeDirectory workPath
        file = takeFileName workPath
        cmdArgs = map (replacePlaceholder file) (cmdTemplate config)
        (cmd : args) = if null (cmdTemplate config) then ["echo", file] else cmdArgs

    -- Run with Timeout (redirect stdout/stderr to avoid mixing with Tar stream)
    let runCmd = withCreateProcess ((proc cmd args) {cwd = Just dir, std_in = NoStream, std_out = NoStream, std_err = Inherit}) $ \_ _ _ ph -> waitForProcess ph

    exitCode <- timeout (timeoutSec config * 1000000) runCmd

    case exitCode of
      Nothing -> throwString "Timeout"
      Just _ ->
        do
          -- Collect results
          subFiles <- listDirectoryRecursive dir
          forM subFiles $ \subPath -> do
            let fullSubPath = dir </> subPath
            isFile <- doesFileExist fullSubPath
            if isFile
              then do
                let entryName = (takeDirectory path) </> subPath
                c <- BL.readFile fullSubPath
                case Tar.toTarPath False entryName of
                  Right tp -> return (Just $ Tar.fileEntry tp c)
                  Left _ -> return Nothing
              else return Nothing
          >>= return
          . catMaybes
  where
    replacePlaceholder f template =
      let f' = T.pack f
          t' = T.pack template
       in T.unpack (T.replace "{}" f' t')

-- | Writes a lazy ByteString to Handle but strips the last 1024 bytes (EOA)
-- This is necessary because `Tar.write` adds EOA, but we want to concatenate streams.
writeStrippingEOA :: Handle -> BL.ByteString -> IO ()
writeStrippingEOA h bs = do
  let (window, rest) = BL.splitAt 1024 bs
  loop window (BL.toChunks rest)
  where
    loop _ [] = return () -- Window contains EOA, discard.
    loop window (c : cs) = do
      let combined = window `BL.append` BL.fromStrict c
          n = fromIntegral (BS.length c)
          (toWrite, newWindow) = BL.splitAt n combined
      BL.hPut h toWrite
      loop newWindow cs

-- | Recursive list
listDirectoryRecursive :: FilePath -> IO [FilePath]
listDirectoryRecursive dir = do
  names <- listDirectory dir
  paths <- forM names $ \name -> do
    let path = dir </> name
    isDirectory <-
      doesFileExist path >>= \case
        True -> return False
        False -> return True
    if isDirectory
      then do
        subs <- listDirectoryRecursive path
        return $ map (name </>) subs
      else return [name]
  return $ concat paths

withSystemTempDirectory :: FilePath -> (FilePath -> IO a) -> IO a
withSystemTempDirectory template action = do
  sysTmp <- getTemporaryDirectory
  let dir = sysTmp </> template
  now <- getCurrentTime
  tid <- myThreadId
  let t = diffUTCTime now (UTCTime (ModifiedJulianDay 0) 0)
      tStr = show t :: Text
      tidStr = show tid :: Text
      -- Use tid to ensure uniqueness across threads
      runDir = dir <> "-" <> (take 10 $ T.unpack tStr) <> "-" <> (filter (/= ' ') $ T.unpack tidStr)
  bracket
    (createDirectoryIfMissing True runDir >> return runDir)
    (\d -> tryAny (removeDirectoryRecursive d) >> return ())
    action

logInfo :: Text -> IO ()
logInfo msg = hPutStrLn stderr $ "[tar-map] " <> msg
