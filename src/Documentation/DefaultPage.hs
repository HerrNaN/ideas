module Documentation.DefaultPage where

import Common.Context
import Common.Exercise
import Common.Transformation
import Control.Monad
import Service.ServiceList
import Service.Revision
import System.Environment
import System.Directory
import System.FilePath
import Text.HTML
import Data.Char

generatePage :: String -> HTML -> IO ()
generatePage txt doc = do
   dir <- targetDirectory
   let filename = dir ++ "/" ++ txt
       dirpart  = takeDirectory filename
   putStrLn $ "Generating " ++ filename
   unless (null dirpart) (createDirectoryIfMissing True dirpart)
   writeFile filename (showHTML doc)

defaultPage :: String -> Int -> HTMLBuilder -> HTML
defaultPage title level builder = htmlPage title (Just (up level ++ "ideas.css")) $ do
   header level
   builder
   footer 

header :: Int -> HTMLBuilder
header level = center $ do
   let f m = text "[" >> space >> m >> space >> text "]"
   f $ link (up level ++ exerciseOverviewPageFile) $ text "Exercises"
   replicateM 5 space
   f $ link (up level ++ "services.html")  $ text "Services"
   replicateM 5 space
   f $ link (up level ++ "tests.html")  $ text "Tests"
   replicateM 5 space
   f $ link (up level ++ "coverage/hpc_index.html")  $ text "Coverage"
   replicateM 5 space
   f $ link (up level ++ "api/index.html")  $ text "API"
   hr

footer :: HTMLBuilder
footer = do 
   hr 
   italic $ text $ "Automatically generated from sources: version " ++
      version ++ "  (revision " ++ show revision ++ ", " ++ lastChanged ++ ")"

up :: Int -> String
up = concat . flip replicate "../"

------------------------------------------------------------
-- Paths and files

ruleImagePath :: Exercise a -> String
ruleImagePath ex = "exercises/" ++ f (domain ex) ++ "/" ++ f (description ex) ++ "/"
 where f = filter isAlphaNum . map toLower

exercisePagePath :: Exercise a -> String
exercisePagePath ex = "exercises/" ++ domain ex ++ "/"

servicePagePath :: String
servicePagePath = "services/" 

ruleImageFile :: Exercise a -> Rule (Context a) -> String
ruleImageFile ex r = ruleImagePath ex ++ "rule" ++ name r ++ ".png"

ruleImageFileHere :: Exercise a -> Rule (Context a) -> String
ruleImageFileHere ex r = filter (not . isSpace) (identifier ex) ++ "/rule" ++ name r ++ ".png"

exerciseOverviewPageFile :: String
exerciseOverviewPageFile = "exercises.html"

serviceOverviewPageFile :: String
serviceOverviewPageFile = "services.html"

exercisePageFile :: Exercise a -> String
exercisePageFile ex = exercisePagePath ex ++ filter (not . isSpace) (identifier ex) ++ ".html"

exerciseDerivationsFile :: Exercise a -> String
exerciseDerivationsFile ex = exercisePagePath ex ++ filter (not . isSpace) (identifier ex) ++ "-derivations.html"

servicePageFile :: Service a -> String
servicePageFile srv = servicePagePath ++ serviceName srv ++ ".html"

------------------------------------------------------------
-- Utility functions

showBool :: Bool -> String 
showBool b = if b then "yes" else "no"

targetDirectory :: IO String
targetDirectory = do
   args <- getArgs
   case args of
      [dir] -> return dir
      _     -> return "docs"