import           Disorder.Core.Main

main :: IO ()
main =
  disorderCliMain [
      "./dist/build/tsrp/tsrp"
    ]
