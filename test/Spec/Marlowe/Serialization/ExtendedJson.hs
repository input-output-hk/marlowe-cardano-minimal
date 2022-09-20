-----------------------------------------------------------------------------
--
-- Module      :  $Headers
-- License     :  Apache 2.0
--
-- Stability   :  Experimental
-- Portability :  Portable
--
-- | This suite tests the Json serialization of the Marlowe extended module
--
-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

module Spec.Marlowe.Serialization.ExtendedJson
  ( tests
  ) where

import Data.Aeson (eitherDecodeFileStrict)
import Language.Marlowe.Extended.V1 (Contract, Module)
import System.Directory (getCurrentDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase)

tests :: TestTree
tests = testGroup "Extended Contract Serialization"
    [ testCase "Golden Swap contract" testGoldenSwapContract
    , testCase "Golden Swap module" testGoldenSwapModule
    ]

-- TODO: Do a small non-property round-trip with example contracts.


-- | Checks that we can decode the Golden JSON Contract for Swap
testGoldenSwapContract :: IO ()
testGoldenSwapContract = do
    filePath <- (\d -> d ++ "/test/Spec/Marlowe/Serialization/golden/swap-contract.json") <$> getCurrentDirectory
    mContract <- eitherDecodeFileStrict filePath
    case mContract of
        Left err              -> assertFailure err
        Right (_ :: Contract) -> return ()

-- | Checks that we can decode the Golden JSON Module for Swap
-- | TODO: If we are more of these tests, add a helper function with a Proxy type
testGoldenSwapModule :: IO ()
testGoldenSwapModule = do
    filePath <- (\d -> d ++ "/test/Spec/Marlowe/Serialization/golden/swap-module.json") <$> getCurrentDirectory
    mContract <- eitherDecodeFileStrict filePath
    case mContract of
        Left err            -> assertFailure err
        Right (_ :: Module) -> return ()
