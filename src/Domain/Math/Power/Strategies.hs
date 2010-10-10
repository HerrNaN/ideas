{-# OPTIONS -XNoMonomorphismRestriction #-}
-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  alex.gerdes@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.Power.Strategies
   ( powerStrategy
   , powerOfStrategy
   , calcPowerStrategy
   , nonNegExpStrategy
   , powerEquationStrategy
   , expEqStrategy
   , logEqStrategy
   ) where

import Common.Classes
import Common.Context
import Common.Exercise
import Common.Strategy
import Common.Transformation
import Common.View
import Data.Maybe
import Domain.Math.Data.Relation
import Domain.Math.Data.OrList
import Domain.Math.Expr
import Domain.Math.Equation.CoverUpRules --(coverUpNegate, coverUpRules)
import Domain.Math.Polynomial.Strategies (quadraticStrategy)
import Domain.Math.Power.Rules
import Domain.Math.Power.NormViews (myRationalView)
import Domain.Math.Numeric.Rules
import Domain.Math.Numeric.Views
import Prelude hiding (repeat, not)

------------------------------------------------------------
-- Strategies

logEqStrategy :: LabeledStrategy (Context (OrList (Relation Expr)))
logEqStrategy = cleanUpStrategy cleanup strat
  where 
    strat   = label "" $ (use logarithm) <*> quadraticStrategy
    cleanup = applyTop (fmap (mapRight (simplify myRationalView)))

powerEquationStrategy :: LabeledStrategy (Context (Relation Expr))
powerEquationStrategy = cleanUpStrategy cleanup strat
  where 
    strat = label "" $
      repeat (  try (use scaleConFactor)
            <*> option (somewhere (use greatestPower) <*> use commonPower)
            <*> (use nthRoot <|> use nthPower <|> use varLeftConRight)
             )
            <*> try (liftToContext approxPower)
    
    cleanup = applyD $ repeat $ alternatives $ map (somewhere . use) $ 
                fractionPlus : naturalRules ++ rationalRules

expEqStrategy :: LabeledStrategy (Context (Equation Expr))
expEqStrategy = cleanUpStrategy cleanup strat
  where 
    strat =  label "" 
          $  coverup
         <*> try (somewhere (use factorAsPower))
         <*> powerS 
         <*> (use sameBase <|> use equalsOne)
         <*> try (use varLeftConRight)
         <*> coverup
    
    cleanup = applyD $ repeat $ alternatives $ map (somewhere . use) $ 
                simplifyProduct : natRules ++ rationalRules
    natRules =
      [ calcPlusWith     "nat" myNatView
      , calcMinusWith    "nat" myNatView
      , calcTimesWith    "nat" myNatView
      , calcDivisionWith "nat" myNatView
      , doubleNegate
      , negateZero
      ]

    coverup = repeat $ alternatives $ map use coverUpRules

    powerS = repeat $ somewhere $  use root2powerG
                               <|> use addExponentsG
                               <|> use subExponents
                               <|> use mulExponents
                               <|> use reciprocalG
                               <|> use reciprocalFor

------------------------------------------------------------------------------

powerStrategy :: LabeledStrategy (Context Expr)
powerStrategy = makeStrategy "simplify" rules cleanupRules
  where 
    rules = powerRules 
    cleanupRules = calcPower : naturalRules ++ rationalRules

powerOfStrategy :: LabeledStrategy (Context Expr)
powerOfStrategy = makeStrategy "write as power of" rules cleanupRules
  where
   rules = powerRules 
   cleanupRules = calcPower 
                : simplifyRoot 
                : simplifyFraction 
                : naturalRules 
               ++ rationalRules

nonNegExpStrategy :: LabeledStrategy (Context Expr)
nonNegExpStrategy = cleanUpStrategy cleanup $ strategise "non neg exponent" rules
  where
    rules = [ addExponents
            , subExponents
            , mulExponents
            , reciprocalInv
            , distributePower
            , distributePowerDiv
            , power2root
            , distributeRoot
            , zeroPower
            , calcPowerPlus
            , calcPowerMinus
            , myFractionTimes
            , reciprocalFrac
            ] ++ fractionRules
    cleanup = applyD $ repeat $ alternatives $
                simp : (map (somewhere . liftToContext) $ calcPower : naturalRules)
    simp = (liftToContext simplifyFraction) <*> not (somewhere $ liftToContext myFractionTimes)

calcPowerStrategy :: LabeledStrategy (Context Expr)
calcPowerStrategy = makeStrategy "calcPower" rules cleanupRules
  where
    rules = calcPower 
          : mulRootCom
          : divRoot 
          : rationalRules
    cleanupRules = rationalRules ++ naturalRules

------------------------------------------------------------
-- | Help functions

makeStrategy :: String -> [Rule Expr] -> [Rule Expr] -> LabeledStrategy (Context Expr)
makeStrategy l rs cs = cleanUpStrategy f $ strategise l rs
  where
    f = applyD $ strategise l cs

strategise l = label l . repeat . alternatives . map (somewhere . liftToContext)
--    strategise l = label l . Common.Strategy.replicate 100 . try . alternatives . map (somewhere . liftToContext)

powerRules =
      [ addExponents
      , subExponents
      , mulExponents
      , distributePower
      , zeroPower
      , reciprocal
      , root2power
      , distributeRoot
      , calcPower
      , calcPowerPlus
      , calcPowerMinus
      , myFractionTimes
      , pushNegOut
      ]

-- | Allowed numeric rules
naturalRules =
   [ calcPlusWith     "nat" myNatView
   , calcMinusWith    "nat" myNatView
   , calcTimesWith    "nat" myNatView
   , calcDivisionWith "nat" myNatView
   , doubleNegate
   , negateZero
   , plusNegateLeft
   , plusNegateRight
   , minusNegateLeft
   , minusNegateRight
   , timesNegateLeft
   , timesNegateRight   
   , divisionNegateLeft
   , divisionNegateRight  
   ]

myNatView = makeView f fromInteger
  where
    f (Nat n) = Just n
    f _       = Nothing
 
rationalRules =    
   [ calcPlusWith     "rational" rationalRelaxedForm
   , calcMinusWith    "rational" rationalRelaxedForm
   , calcTimesWith    "rational" rationalRelaxedForm
   , calcDivisionWith "integer"  integerNormalForm
   , doubleNegate
   , negateZero
   , divisionDenominator
   , divisionNumerator
   , simplerFraction
   ]
   
fractionRules =
   [ fractionPlus, fractionPlusScale, fractionTimes
   , calcPlusWith     "integer" integerNormalForm
   , calcMinusWith    "integer" integerNormalForm
   , calcTimesWith    "integer" integerNormalForm -- not needed?
   , calcDivisionWith "integer" integerNormalForm
   , doubleNegate
   , negateZero
   , smartRule divisionDenominator  
   , smartRule divisionNumerator 
   , simplerFraction
   ]
