module Main where

import Numeric.Natural (Natural)
import System.Exit (exitFailure)
import System.IO (hFlush, stdout, stderr, hPutStrLn)
import Text.Read (readMaybe)

gray :: Natural -> [String]
gray 0 = [""]
gray n =
    let previous = gray (n - 1)
    in map ('0' :) previous ++ map ('1' :) (reverse previous)

main :: IO ()
main = do
    putStr "Enter n >= 0 (try 3): "
    hFlush stdout
    input <- getLine
    case readMaybe input :: Maybe Integer of
        Just n | n >= 0 -> do
            let codes = gray (fromInteger n)
            putStrLn "Gray code (one string per line):"
            mapM_ putStrLn codes
            putStrLn ("Total: " ++ show (2 ^ n :: Integer))
            if n == 0 then putStrLn "The blank line above is the empty string." else pure ()
        _ -> do
            hPutStrLn stderr "Error: enter a non-negative integer."
            exitFailure
