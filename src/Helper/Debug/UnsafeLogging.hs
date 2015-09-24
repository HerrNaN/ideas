module  Helper.Debug.UnsafeLogging where

import System.Process
import System.IO.Unsafe

unsafeLog :: String -> a -> a
unsafeLog message value = unsafePerformIO $ do
  callCommand ("logger " ++ message)
  return value
