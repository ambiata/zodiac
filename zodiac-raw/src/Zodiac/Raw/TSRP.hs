{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Zodiac.Raw.TSRP(
    authedRawRequest
  , hadronAuthHeader
  , httpAuthHeader
  , macHadronRequest
  , rawKeyId
  , verifyRawRequest
  , verifyRawRequest'
  ) where

import           Data.ByteString (ByteString)
import           Data.List.NonEmpty (NonEmpty(..))
import           Data.Semigroup ((<>))
import           Data.Time.Clock (UTCTime, getCurrentTime)

import           Hadron.Core (HTTPRequest(..))
import qualified Hadron.Core as H

import           P hiding ((<>))

import           System.IO (IO)

import           Tinfoil.Data (Verified(..), MAC)

import           Zodiac.Core.Request
import           Zodiac.TSRP.Data
import           Zodiac.TSRP.Symmetric
import           Zodiac.Raw.Error
import           Zodiac.Raw.Request

-- | Authenticate a raw HTTP request. If the request isn't
-- malformed, the output is a ByteString with the necessary
-- Authorization header added which can be sent directly to a server
-- supporting TSRP.
authedRawRequest :: KeyId
                 -> TSRPKey
                 -> RequestExpiry
                 -> ByteString
                 -> RequestTimestamp
                 -> Either RequestError ByteString
authedRawRequest kid sk re bs rt = do
  r <- parseRawRequest bs
  cr <- fromHadronRequest r
  let mac = macRequest TSRPv1 kid rt re cr sk
      authH = httpAuthHeader TSRPv1 kid rt re cr mac
  pure . H.renderHTTPRequest $ addHeader r authH
  where
    addHeader (HTTPV1_1Request req) newH =
      let oldHs = H.unHTTPRequestHeaders $ H.hrqv1_1Headers req
          newHs = H.HTTPRequestHeaders $ (pure newH) <> oldHs in
      HTTPV1_1Request $ req { H.hrqv1_1Headers = newHs }

verifyRawRequest :: KeyId
                 -> TSRPKey
                 -> ByteString
                 -> IO Verified
verifyRawRequest kid sk bs =
  getCurrentTime >>= verifyRawRequest' kid sk bs

verifyRawRequest' :: KeyId
                  -> TSRPKey
                  -> ByteString
                  -> UTCTime
                  -> IO Verified
verifyRawRequest' kid sk bs now =
  case parseRawRequest bs of
    Left _ -> pure NotVerified
    Right req -> case hadronAuthHeader req of
      Left _ -> pure NotVerified
      Right sah -> case fromHadronRequest req of
        Left _ -> pure NotVerified
        Right cr -> verifyRequest kid sk cr sah now

-- | Create a detached MAC of a hadron 'HTTPRequest'.
macHadronRequest :: KeyId
                 -> TSRPKey
                 -> RequestExpiry
                 -> H.HTTPRequest
                 -> RequestTimestamp
                 -> Either RequestError MAC
macHadronRequest kid sk re r rts = do
  cr <- fromHadronRequest r
  pure $ macRequest TSRPv1 kid rts re cr sk

httpAuthHeader :: SymmetricProtocol
               -> KeyId
               -> RequestTimestamp
               -> RequestExpiry
               -> CRequest
               -> MAC
               -> H.Header
httpAuthHeader TSRPv1 kid rt re cr mac =
  let sh = signedHeaders cr
      sah = SymmetricAuthHeader TSRPv1 kid rt re sh mac in
  H.Header H.authorizationHeaderName . pure . H.HeaderValue $
    renderSymmetricAuthHeader sah

-- | Extract the 'KeyId' from a request.
rawKeyId :: ByteString
         -> Either ProtocolError KeyId
rawKeyId bs =
  first (const MalformedRequest) (parseRawRequest bs) >>= (fmap sahKeyId . hadronAuthHeader)

hadronAuthHeader :: HTTPRequest
                 -> Either ProtocolError SymmetricAuthHeader
hadronAuthHeader r =
  case H.lookupRequestHeader r H.authorizationHeaderName of
    Nothing' ->
      Left NoAuthHeader
    Just' (h:|[]) ->
      maybe' (Left MalformedAuthHeader) Right . parseSymmetricAuthHeader $ H.unHeaderValue h
    Just' _ ->
      Left MultipleAuthHeaders
