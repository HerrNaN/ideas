-----------------------------------------------------------------------------
-- Copyright 2009, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.Polynomial.Exercises where

import Control.Monad (mplus)
import Common.Context
import Common.Exercise
import Common.Rewriting hiding (match, matchM)
import Common.Strategy
import Common.Traversable
import Common.Transformation
import Common.View
import Data.Maybe
import Domain.Math.Data.OrList
import Domain.Math.Data.Relation
import Domain.Math.Equation.Views
import Domain.Math.Examples.DWO1
import Domain.Math.Examples.DWO2
import Domain.Math.Expr
import Domain.Math.Expr.Parser
import Domain.Math.Polynomial.BuggyRules
import Domain.Math.Polynomial.CleanUp
import Domain.Math.Polynomial.Rules
import Domain.Math.Polynomial.Strategies
import Domain.Math.Polynomial.Views
import Domain.Math.Numeric.Views

------------------------------------------------------------
-- Exercises

linearExercise :: Exercise (Equation Expr)
linearExercise = makeExercise 
   { description  = "solve a linear equation"
   , exerciseCode = makeCode "math" "lineq"
   , status       = Provisional
   , parser       = parseWith (pEquation pExpr)
   , similarity   = eqRelation cleanUpSimple
   , equivalence  = viewEquivalent linearEquationView
   , isReady      = solvedRelation
   , extraRules   = ignoreContext buggyPlus : linearRules
   , strategy     = mapRules ignoreContext linearStrategy
   , examples     = concat (linearEquations ++ [specialCases])
   }
 where
   specialCases = let x = Var "x" in [5 :==: x, 5 :==: x + 1]

quadraticExercise :: Exercise (OrList (Relation Expr))
quadraticExercise = makeExercise 
   { description  = "solve a quadratic equation"
   , exerciseCode = makeCode "math" "quadreq"
   , status       = Provisional
   , parser       = \input -> case parseWith (pOrList (pEquation pExpr)) input of
                                 Left err -> Left err
                                 Right xs -> Right (build (switchView equationView) xs)
   , similarity   = eqOrList cleanUpExpr2
   , equivalence  = equivalentRelation (viewEquivalent quadraticEquationsView)
   , isReady      = solvedRelations
   , extraRules   = map (ignoreContext . liftRule (switchView equationView)) $ 
                       quadraticRules ++ abcBuggyRules
   , strategy     = quadraticStrategy
   , examples     = map (orList . return . build equationView) (concat quadraticEquations)
   }
   
higherDegreeExercise :: Exercise (OrList (Relation Expr))
higherDegreeExercise = makeExercise 
   { description  = "solve an equation (higher degree)"
   , exerciseCode = makeCode "math" "higherdegree"
   , status       = Provisional
   , parser       = parser quadraticExercise
   , similarity   = eqOrList cleanUpExpr2
   , equivalence  = equivalentRelation (viewEquivalent higherDegreeEquationsView)
   , isReady      = solvedRelations
   , extraRules   = map (ignoreContext . liftRule (switchView equationView)) higherDegreeRules
   , strategy     = higherDegreeStrategy
   , examples     = map (orList . return . build equationView) 
                       (concat $ higherEq1 ++ higherEq2 ++ [higherDegreeEquations])
   }
   
quadraticNoABCExercise :: Exercise (OrList (Relation Expr))
quadraticNoABCExercise = quadraticExercise
   { description  = "solve a quadratic equation without abc-formula"
   , exerciseCode = makeCode "math" "quadreq-no-abc"
   , strategy     = configure cfg quadraticStrategy
   }
 where
   cfg = [ (ByName (name prepareSplitSquare), Expose)
         , (ByName "abc form", Hide)
         ]
         
quadraticWithApproximation :: Exercise (OrList (Relation Expr))
quadraticWithApproximation = quadraticExercise
   { description  = "solve a quadratic equation with approximation"
   , exerciseCode = makeCode "math" "quadreq-with-approx"
   , strategy     = configure cfg quadraticStrategy
   }
 where
   cfg = [ (ByName "approximate result", Expose)
         , (ByName "square root simplification", Hide)
         ]

findFactorsExercise :: Exercise Expr
findFactorsExercise = makeExercise
   { description  = "factorize the expression"
   , exerciseCode = makeCode "math" "factor"
   , status       = Provisional
   , parser       = parseWith pExpr
   , similarity   = \a b -> cleanUpExpr a == cleanUpExpr b
   , equivalence  = viewEquivalent (polyViewWith rationalView)
 --  , isReady      = solvedRelations
   , strategy     = mapRules ignoreContext findFactorsStrategy
   , examples     = concat findFactors
   }

--------------------------------------------
-- Equality

equivalentRelation :: (OrList (Equation a) -> OrList (Equation a) -> Bool) -> OrList (Relation a) -> OrList (Relation a) -> Bool
equivalentRelation f ra rb = fromMaybe False $ do
   a <- switch (fmap (match equationView) ra)
   b <- switch (fmap (match equationView) rb)
   return (f a b)

eqOrList :: (Relational f, Ord (f Expr)) => 
               (Expr -> Expr) -> OrList (f Expr) -> OrList (f Expr) -> Bool
eqOrList f x y = normOrList f x == normOrList f y

eqRelation :: (Relational f, Eq (f Expr)) => 
                 (Expr -> Expr) -> f Expr -> f Expr -> Bool
eqRelation f x y = normRelation f x == normRelation f y

normOrList :: (Relational f, Ord (f Expr)) => 
                 (Expr -> Expr) -> OrList (f Expr) -> OrList (f Expr)
normOrList f = normalize . fmap (normRelation f)

normRelation :: Relational f => (Expr -> Expr) -> f Expr -> f Expr
normRelation f rel
   | leftHandSide new > rightHandSide new && isSymmetric new = flipSides new
   | otherwise = new
 where
   new = fmap (normExpr f) rel

normExpr :: (Expr -> Expr) -> Expr -> Expr
normExpr f = normalizeWith [plusOperator, timesOperator] . f
 where
   plusOperator  = acOperator (+) isPlus
   timesOperator = acOperator (*) isTimes
   
-- TODO: move this definition
buggyPlus :: Rule (Equation Expr)
buggyPlus = buggyRule $ makeSimpleRuleList "buggy plus" $ \(lhs :==: rhs) -> do
   (a, b) <- matchM plusView lhs
   [ a :==: rhs + b, b :==: rhs + a ]
 `mplus` do
   (a, b) <- matchM plusView rhs
   [ lhs + a :==: b, lhs + b :==: a ]