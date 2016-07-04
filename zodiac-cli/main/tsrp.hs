{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

import           BuildInfo_ambiata_zodiac_cli
import           DependencyInfo_ambiata_zodiac_cli

import           Options.Applicative

import           P

import           System.IO
import           System.Exit
import           X.Options.Applicative

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  dispatch parser >>= \sc ->
    case sc of
      VersionCommand ->
        putStrLn buildInfoVersion >> exitSuccess
      DependencyCommand ->
        mapM_ putStrLn dependencyInfo
      RunCommand DryRun c ->
        print c >> exitSuccess
      RunCommand RealRun c ->
        run c

parser :: Parser (SafeCommand Command)
parser =
  safeCommand $ pure Command

run :: Command -> IO ()
run c = case c of
  Command ->
    putStrLn "*implement me*" >> exitFailure

data Command =
  Command
  deriving (Eq, Show)
