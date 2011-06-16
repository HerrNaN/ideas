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
-- Type classes and instances.
--
-----------------------------------------------------------------------------
module Common.Classes 
   ( -- * Type class Apply
     Apply, apply, applyAll, applicable, applyD, applyM
     -- * Type class Container
   , Container, singleton, getSingleton
     -- * Type class BiFunctor
   , BiFunctor, biMap, mapFirst, mapSecond
   ) where

import Common.Utils (safeHead)
import Data.Maybe

import qualified Data.Set as S

-----------------------------------------------------------
-- Type class Apply

-- | A type class for functors that can be applied to a value. Transformation, 
-- Rule, and Strategy are all instances of this type class. 
class Apply t where
   applyAll :: t a -> a -> [a]  -- ^ Returns zero or more results

-- | Returns zero or one results
apply :: Apply t => t a -> a -> Maybe a
apply ta = safeHead . applyAll ta

-- | Checks whether the functor is applicable (at least one result)
applicable :: Apply t => t a -> a -> Bool
applicable ta = isJust . apply ta

-- | If not applicable, return the current value (as default)
applyD :: Apply t => t a -> a -> a
applyD ta a = fromMaybe a (apply ta a)

-- | Same as apply, except that the result (at most one) is returned in some monad
applyM :: (Apply t, Monad m) => t a -> a -> m a
applyM ta = maybe (fail "applyM") return . apply ta

-----------------------------------------------------------
-- Type class Container

-- | Instances should satisfy the following law: @getSingleton . singleton == Just@
class Container f where
   singleton    :: a   -> f a
   getSingleton :: f a -> Maybe a

instance Container [] where
   singleton        = return
   getSingleton [a] = Just a
   getSingleton _   = Nothing
   
instance Container S.Set where
   singleton    = S.singleton
   getSingleton = getSingleton . S.toList
   
-----------------------------------------------------------
-- Type class BiFunctor

class BiFunctor f where
   biMap     :: (a -> c) -> (b -> d) -> f a b -> f c d
   mapFirst  :: (a -> b) -> f a c -> f b c
   mapSecond :: (b -> c) -> f a b -> f a c
   -- default definitions
   mapFirst  = flip biMap id
   mapSecond = biMap id

instance BiFunctor Either where
   biMap f g = either (Left . f) (Right . g)

instance BiFunctor (,) where
  biMap f g (a, b) = (f a, g b)