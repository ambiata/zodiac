{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Test.Zodiac.TSRP.HttpClient where

import           Disorder.Core.Property (failWith)
import           Disorder.Core.Run (ExpectedTestSpeed(..), disorderCheckEnvAll)

import           Network.HTTP.Client (requestHeaders)

import           P

import           System.IO (IO)

import           Test.Zodiac.Arbitrary ()
import           Test.QuickCheck
import           Test.QuickCheck.Instances ()

import           Tinfoil.Data (HashFunction, SymmetricKey)

import           Zodiac.Data
import           Zodiac.Request.HttpClient
import           Zodiac.TSRP.HttpClient

prop_authedHttpClientRequest :: SymmetricProtocol
                             -> HashFunction
                             -> CRequest
                             -> KeyId
                             -> SymmetricKey
                             -> RequestExpiry
                             -> RequestTimestamp
                             -> Property
prop_authedHttpClientRequest sp hf cr kid sk re rt =
  let req = fromCanonicalRequest cr
      res = authedHttpClientRequest sp hf kid sk re req rt in
  case res of
    Left e -> failWith $ "authentication unexpectedly failed: " <> renderRequestError e
    Right req' ->
      let hs = requestHeaders req'
          ahs = filter ((== "authorization") . fst) hs in
      case ahs of
        [] -> failWith $ "no authentication header in authenticated request"
        auths ->
          -- Tests can generate "authorization" as a header name, so we just
          -- want to make sure our one is in there.
          any validAuthHeader auths === True
  where
    validAuthHeader (_hn, hv) = case parseSymmetricAuthHeader hv of
      Just' _ -> True
      Nothing' -> False

return []
tests :: IO Bool
tests = $disorderCheckEnvAll TestRunMore
