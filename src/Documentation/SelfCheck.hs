-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Documentation.SelfCheck (selfCheck, blackBoxTests) where

import System.Directory
import Common.TestSuite
import Common.Utils (useFixedStdGen, Some(..), snd3)
import Common.Exercise
import Service.ExercisePackage
import Control.Monad
import Service.Request
import Service.DomainReasoner
import Service.ModeJSON
import Service.ModeXML
import qualified Text.OpenMath.Tests as OpenMath
import qualified Text.UTF8 as UTF8
import qualified Text.JSON as JSON
import Data.List

selfCheck :: String -> DomainReasoner TestSuite
selfCheck dir = do
   pkgs        <- getPackages
   domainSuite <- getTestSuite
   run         <- runWithCurrent
   
   return $ do
      suite "Framework checks" $ do
         suite "Text encodings" $ do
            addProperty "UTF8 encoding" UTF8.propEncoding
            addProperty "JSON encoding" JSON.propEncoding
            addProperty "OpenMath encoding" OpenMath.propEncoding
         
      suite "Domain checks" domainSuite
      
      suite "Exercise checks" $
         forM_ pkgs $ \(Some pkg) ->
            exerciseTestSuite (exercise pkg)
      
      suite "Black box tests" $ do 
         liftIO (blackBoxTests run dir) >>= id

-- Returns the number of tests performed
blackBoxTests :: (DomainReasoner Bool -> IO Bool) -> String -> IO TestSuite
blackBoxTests run path = do
   putStrLn ("Scanning " ++ path)
   -- analyse content
   xs0 <- getDirectoryContents path
   let (xml,  xs1) = partition (".xml"  `isSuffixOf`) xs0
       (json, xs2) = partition (".json" `isSuffixOf`) xs1
   -- perform tests
   ts1 <- forM json $ \x ->
             doBlackBoxTest run JSON (path ++ "/" ++ x)
   ts2 <- forM xml $ \x ->
             doBlackBoxTest run XML (path ++ "/" ++ x)
   -- recursively visit subdirectories
   ts3 <- forM (filter ((/= ".") . take 1) xs2) $ \x -> do
             let p = path ++ "/" ++ x
             valid <- doesDirectoryExist p
             if not valid 
                then return (return ())
                else liftM (suite $ "Directory " ++ simplerDirectory p) 
                           (blackBoxTests run p)
   return $ 
      sequence_ (ts1 ++ ts2 ++ ts3)

doBlackBoxTest :: (DomainReasoner Bool -> IO Bool) -> DataFormat -> FilePath -> IO TestSuite
doBlackBoxTest run format path = do
   b <- doesFileExist expPath
   return $ if not b 
      then warn $ expPath ++ " does not exist"
      else assertIO (stripDirectoryPart path) $ run $ do 
         -- Comparing output with expected output
         liftIO useFixedStdGen -- fix the random number generator
         txt  <- liftIO $ readFile path
         expt <- liftIO $ readFile expPath
         out  <- case format of 
                    JSON -> liftM snd3 (processJSON txt)
                    XML  -> liftM snd3 (processXML txt)
         -- Conditional forces evaluation of the result, to make sure that
         -- all file handles are closed afterwards.
         if out ~= expt then return True else return False
       `catchError` 
         \_ -> return False
 where
   expPath = baseOf path ++ ".exp"
   baseOf  = reverse . drop 1 . dropWhile (/= '.') . reverse
   x ~= y  = filterVersion x == filterVersion y
   
   filterVersion = 
      let p s = not (null s || "version" `isInfixOf` s)
      in unlines . filter p . lines

simplerDirectory :: String -> String
simplerDirectory s
   | "../"   `isPrefixOf` s = simplerDirectory (drop 3 s)
   | "test/" `isPrefixOf` s = simplerDirectory (drop 5 s)
   | otherwise = s

stripDirectoryPart :: String -> String
stripDirectoryPart = reverse . takeWhile (/= '/') . reverse

{-
logicConfluence :: IO ()
logicConfluence = reportTest "logic rules" (isConfluent f rs)
 where
   f    = normalizeWith ops . normalFormWith ops rs
   ops  = map makeCommutative Logic.logicOperators
   rwrs = Logic.logicRules \\ [Logic.ruleOrOverAnd, Logic.ruleCommOr, Logic.ruleCommAnd]
   rs   = [ r | RewriteRule r <- concatMap transformations rwrs ]
   -- eqs  = bothWays [ r | RewriteRule r <- concatMap transformations Logic.logicRules ]
-}