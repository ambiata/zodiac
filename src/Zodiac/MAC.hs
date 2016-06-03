{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

{-
HMAC functionality for symmetric request-signing.

Don't use this module directly unless you know what you're doing.
-}
module Zodiac.MAC(
    deriveRequestKey
  ) where

import           P

import           Tinfoil (SymmetricKey(..), KeyId(..), MAC(..))
import           Tinfoil.MAC (hmacSHA256)

import           Zodiac.Data

macProtocol :: Protocol
macProtocol = TSRPv1

-- | Derive the key we actually use to sign the request from the
-- secret key, the key ID and the date part of the request timestamp
-- via an iterated chain of keyed hashes.
deriveRequestKey :: RequestTimestamp -> KeyId -> SymmetricKey -> SymmetricKey
deriveRequestKey ts (KeyId kid) (SymmetricKey sk) =
  let k0 = SymmetricKey $ sk <> renderTimestampDate ts
      k1 = chainNext $ hmacSHA256 k0 prefix
      k2 = chainNext $ hmacSHA256 k1 kid
      k3 = chainNext $ hmacSHA256 k2 suffix in
  k3
  where
    prefix = renderProtocol macProtocol <> "-start"

    suffix = renderProtocol macProtocol <> "-end"

    chainNext = SymmetricKey . unMAC