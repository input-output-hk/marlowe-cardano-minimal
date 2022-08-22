
module Spec.Marlowe.Semantics.AssocMap (
  assocMapAdd
, assocMapEq
, assocMapInsert
, assocMapSort
, assocMapValid
, assocMapMember
, assocMapLookup
) where


import Data.Bifunctor (bimap)
import Data.Function (on)
import Data.List (groupBy, nub, sortBy)

import qualified PlutusTx.AssocMap as AM (Map, fromList, toList)


assocMapValid :: Eq k => AM.Map k v -> AM.Map k v
assocMapValid am =
  let
    keys = fst <$> AM.toList am
  in
    if nub keys == keys
      then am
      else error "Duplicate keys in PlutusTx.AssocMap.Map."


assocMapSort :: Ord k => AM.Map k v -> AM.Map k v
assocMapSort = AM.fromList . sortBy (compare `on` fst) . AM.toList


assocMapEq :: Ord k => Eq v => AM.Map k v -> AM.Map k v -> Bool
assocMapEq = (==) `on` assocMapSort


assocMapInsert :: Eq k => k -> v -> AM.Map k v -> AM.Map k v
assocMapInsert k v =
  AM.fromList
    . ((k, v) :)
    . filter ((/= k) . fst)
    . AM.toList


assocMapAdd :: Ord k => Num v => k -> v -> AM.Map k v -> AM.Map k v
assocMapAdd k v =
  AM.fromList
    . fmap (bimap head sum . unzip)
    . groupBy ((==) `on` fst)
    . sortBy (compare `on` fst)
    . ((k, v) :)
    . AM.toList


assocMapMember :: Eq k => k -> AM.Map k v -> Bool
assocMapMember k = any ((== k) . fst) . AM.toList


assocMapLookup :: Eq k => k -> AM.Map k v -> Maybe v
assocMapLookup k = lookup k . AM.toList
