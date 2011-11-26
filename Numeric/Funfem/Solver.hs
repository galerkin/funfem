---------------------------------------------------------------------------------- 
-- |
-- Module : Solver
-- Copyright : (c) Adrien Haxaire 2011
-- Licence : BSD3
--
-- Maintainer : Adrien Haxaire <adrien@funfem.org>
-- Stability : experimental
-- Portabilty : not tested
--
----------------------------------------------------------------------------------
--

module Numeric.Funfem.Solver where

import Numeric.Funfem.Vector
import Numeric.Funfem.Matrix

import qualified Data.List as L

eps :: Double
eps = 1.0e-3

-- | Solves Ax = b. Arguments are passed in this order. No first guess on x is made, so 
-- it should be initialized first.
cg :: Matrix -> Vector -> Vector -> Vector
cg a x b = if norm r <= eps then x else cg' a x r r r
  where
    r = b - multMV a x

cg' :: Matrix -> Vector -> Vector -> Vector -> Vector -> Vector
cg' a x r z p = if norm r' <= eps then x' else cg' a x' r' z' p'
  where
    alpha = (r .* z) / (p .* multMV a p)
    beta = (z' .* r') / (z .* r)
    x' = x + vmap (*alpha) p
    r' = r - vmap (*alpha) (multMV a p)
    z' = r'    
    p' = z'+ vmap (*beta) p


-- | LU decomposition and back substitution

-- stores only non zero values
upper :: [[Double]] -> [[Double]]
upper [] = []
upper x = L.head upped : upper minored
  where
    upped = up x
    minored = minor up x

up :: [[Double]] -> [[Double]]
up [] = []
up (r:rs) = r : up' r rs 

up' :: [Double] -> [[Double]] -> [[Double]]
up' _ [] = []
up' r (l:ls) = zipWith (-) l (L.map (*h) r) : up' r ls
  where
    h = L.head l / L.head r 
    
    
-- stores only non zero values    
lower :: [[Double]] -> [[Double]]
lower [] = []
lower m = L.reverse . rearrange . low $ m


rearrange :: [[Double]] -> [[Double]]
rearrange [] = []
rearrange m = (arrange $ m) : (rearrange $ minor' id m)
    
arrange = L.reverse . L.map (L.last) . L.transpose



low :: [[Double]] -> [[Double]]
low [] = []
low (l:ls) = (column (d:ds)) : minored
  where
    h = L.head l 
    (d:ds) = (L.map . L.map) (/h) (l:ls)
    minored = low $ minor id $ up' d (d:ds)

column [] = []
column (l:ls) = L.head l : column ls  


minor :: ([a] -> [[b]]) -> [a] -> [[b]]
minor _ [] = []
minor f xs = L.tail [L.tail x | x <- f xs]

-- minor' :: ([a] -> [[b]]) -> [a] -> [[b]]
minor' _ [] = []
minor' f xs = L.init [L.init x | x <- f xs]




-- find y / Ly = b
findY :: [Double] -> [[Double]] -> [Double]
findY _ [] = []
findY b (l:ls) = (L.head row - rest) : findY b ls
  where
    row = zipWith (*) b l
    rest = L.sum (L.tail row)
    

-- find x / Ux = b
findX :: [Double] -> [Double] -> [[Double]] -> [Double]    
findX _ _ [] = []
findX b y (u:us) = ((yi - L.sum row) / uii) : findX b y us
  where
    uii = L.head u
    yi = y !! (L.length u -1)
    row = zipWith (*) b (L.tail u)
    
-- | Solves Ax = b using LU decomposition    
luSolve :: Matrix -> Vector -> Vector
luSolve m b = fromList $ findX b' y (upper m')
  where
    m' = fromMatrix' m 
    b' = fromVector b
    y = findY b' (lower m')
    