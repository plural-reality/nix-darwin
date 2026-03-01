{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

-- | url2content: Pure 1:1 filter — stdin URL → stdout content
-- Replaces urls2contents.hs (N→N) with a composable primitive.
-- Compose via: tar-map --stdio -- url2content

import Protolude hiding (try)
import Network.HTTP.Req
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Control.Exception.Safe (try, SomeException)
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import System.Process (readProcess)
import Text.URI (mkURI)
import qualified System.IO.Error

main :: IO ()
main = do
  url <- T.strip <$> TIO.getContents
  content <- fetchAndExtract url
  TIO.putStr content

fetchAndExtract :: Text -> IO Text
fetchAndExtract url =
  runReq defaultHttpConfig $
    case mkURI url of
      Nothing -> liftIO $ throwIO $ System.IO.Error.userError "Invalid URL format"
      Just uri ->
        case useURI uri of
          Nothing -> liftIO $ throwIO $ System.IO.Error.userError "Unsupported URL scheme"
          Just (Left (urlHttp, opts)) ->
            req GET urlHttp NoReqBody bsResponse opts >>= handleResponse url
          Just (Right (urlHttps, opts)) ->
            req GET urlHttps NoReqBody bsResponse opts >>= handleResponse url

handleResponse :: Text -> BsResponse -> Req Text
handleResponse url r =
  let body = responseBody r
      bodyText = decodeUtf8With lenientDecode body
      isHtml = "html" `T.isInfixOf` url
            || "<html" `T.isInfixOf` (T.toLower $ T.take 100 bodyText)
  in if isHtml
       then liftIO $ extractWithTrafilatura bodyText
       else return bodyText

extractWithTrafilatura :: Text -> IO Text
extractWithTrafilatura htmlContent = do
  output <- try $ readProcess "trafilatura" [] (T.unpack htmlContent)
  case output of
    Left e  -> return $ "(Trafilatura execution failed: " <> show (e :: SomeException) <> ")"
    Right res -> return $ T.pack res
