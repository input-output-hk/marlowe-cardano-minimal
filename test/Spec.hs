{-# LANGUAGE OverloadedStrings #-}

module Main(main) where

-- import qualified Spec.Marlowe.AutoExecute
import qualified Spec.Marlowe.Marlowe

import qualified Spec.Marlowe.Marlowe as Spec.Marlowe.Semantics
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.QuickCheck (testProperty)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Marlowe"
    [ testGroup "Contracts"
        [ Spec.Marlowe.Marlowe.tests
    --    PAB tests
    --    , Spec.Marlowe.AutoExecute.tests
    --     -- Does not work when invoking it from nix
    --     -- , testProperty "Correct Show instance for Contract"
    --     --  Spec.Marlowe.Marlowe.prop_showWorksForContracts
        ]
    , testGroup "Static Analysis"
        [ testProperty "No false positives" Spec.Marlowe.Marlowe.prop_noFalsePositives
        ]
    , testGroup "Marlowe JSON"
        [ testProperty "Serialise deserialise loops" Spec.Marlowe.Marlowe.prop_jsonLoops
        ]
    , Spec.Marlowe.Semantics.tests
    ]

