{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
module Zodiac.Core.Data.Time(
    RequestDate(..)
  , RequestExpired(..)
  , RequestExpiry(..)
  , RequestTimestamp(..)

  , maxClockSkew
  , maxRequestExpiry
  , parseRequestExpiry
  , parseRequestTimestamp
  , renderRequestDate
  , renderRequestExpiry
  , renderRequestTimestamp
  , timestampDate
  ) where

import           Control.DeepSeq.Generics (genericRnf)

import qualified Data.Attoparsec.ByteString as AB
import qualified Data.Attoparsec.ByteString.Char8 as ABC
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BSC
import qualified Data.Text.Encoding as T
import           Data.Time.Calendar (Day(..))
import           Data.Time.Clock (UTCTime(..), NominalDiffTime)
import           Data.Time.Format (formatTime, iso8601DateFormat)
import           Data.Time.Format (defaultTimeLocale, parseTimeM)


import           GHC.Generics (Generic)

import           P

-- | Whether the request being processed is beyond its expiry window.
data RequestExpired =
    TimeExpired
  | TimeValid
  | NotYetValid
  deriving (Eq, Show, Generic)

instance NFData RequestExpired where rnf = genericRnf

-- | Time at which the request is made. Precision is to the second.
newtype RequestTimestamp =
  RequestTimestamp {
    unRequestTimestamp :: UTCTime
  } deriving (Eq, Show, Generic)

instance NFData RequestTimestamp where rnf = genericRnf

requestTimestampFormat :: [Char]
requestTimestampFormat =
  iso8601DateFormat $ Just "%H:%M:%S"

renderRequestTimestamp :: RequestTimestamp -> ByteString
renderRequestTimestamp (RequestTimestamp ts) =
  let str = formatTime defaultTimeLocale requestTimestampFormat ts in
  BSC.pack str

parseRequestTimestamp :: ByteString -> Maybe' RequestTimestamp
parseRequestTimestamp =
  fmap RequestTimestamp . strictMaybe .
    parseTimeM False defaultTimeLocale requestTimestampFormat . BSC.unpack

-- | Date on which a request is made (UTC).
newtype RequestDate =
  RequestDate {
    unRequestDate :: Day
  } deriving (Eq, Generic)

instance NFData RequestDate where rnf = genericRnf

instance Show RequestDate where
  show = BSC.unpack . renderRequestDate

timestampDate :: RequestTimestamp -> RequestDate
timestampDate = RequestDate . utctDay . unRequestTimestamp

-- | Render just the date part in ISO-8601 format.
renderRequestDate :: RequestDate -> ByteString
renderRequestDate (RequestDate rd) =
  let ts = UTCTime rd 0
      fmt = iso8601DateFormat Nothing
      str = formatTime defaultTimeLocale fmt ts in
  BSC.pack str

-- | Number of seconds for a request to be considered valid - after
-- this time, an application server will discard it.
newtype RequestExpiry =
  RequestExpiry {
    unRequestExpiry :: Int
  } deriving (Eq, Show, Generic)

instance NFData RequestExpiry where rnf = genericRnf

renderRequestExpiry :: RequestExpiry -> ByteString
renderRequestExpiry = T.encodeUtf8 . renderIntegral . unRequestExpiry

-- | Maximum value for request expiry, in seconds (365 days).
maxRequestExpiry :: Int
maxRequestExpiry = 31536000

-- | Maximum forwards clock skew - if we receive a timestamp after
-- ten minutes after the current time, we reject the request.
maxClockSkew :: NominalDiffTime
maxClockSkew = fromIntegral (600 :: Int)

parseRequestExpiry :: ByteString -> Maybe' RequestExpiry
parseRequestExpiry bs =
  case AB.parseOnly (ABC.decimal <* AB.endOfInput) bs of
    -- Check it's at least one second and at most one year.
    Right x -> if x > 0 && x <= maxRequestExpiry
                 then pure $ RequestExpiry x
                 else Nothing'
    -- Don't want to propagate errors up from 'symmetricAuthHeaderP' at this point.
    Left _ -> Nothing'
