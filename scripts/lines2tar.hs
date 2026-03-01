{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

-- | lines2tar: Natural transformation Lines → Tar
-- Reads line-delimited strings from stdin, emits a tar stream on stdout.
-- Each entry: path = sanitized string, body = original line.
-- Compose: echo -e "https://example.com\nhttps://foo/page" | lines2tar | tar tf -

import Protolude
import qualified Codec.Archive.Tar as Tar
import qualified Codec.Archive.Tar.Entry as Tar
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Encoding as TE
import System.IO (hSetBinaryMode)

main :: IO ()
main = do
  hSetBinaryMode stdout True
  contents <- TIO.getContents
  let entries = mapMaybe lineToEntry (filter (not . T.null) (T.lines contents))
  BL.hPut stdout (Tar.write entries)

-- | Convert a line to a tar entry.
-- Path: sanitized for filesystem. Body: original line text.
lineToEntry :: Text -> Maybe Tar.Entry
lineToEntry line =
  case Tar.toTarPath False (T.unpack (sanitize line)) of
    Right tp -> Just $ Tar.fileEntry tp (BL.fromStrict $ TE.encodeUtf8 line)
    Left _   -> Nothing

-- | Sanitize a URL into a filesystem-safe relative path.
-- Strips scheme, query, fragment. Trailing "/" becomes "/index".
sanitize :: Text -> Text
sanitize =
  appendIndex
  . stripQueryFragment
  . stripScheme
  where
    stripScheme t = maybe t identity
      $ T.stripPrefix "https://" t
      <|> T.stripPrefix "http://" t
    stripQueryFragment = T.takeWhile (\c -> c /= '?' && c /= '#')
    appendIndex t
      | T.isSuffixOf "/" t = t <> "index"
      | otherwise          = t
