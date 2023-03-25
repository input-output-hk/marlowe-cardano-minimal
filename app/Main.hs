
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}


module Main (
  main
) where


import Control.Monad.Except (runExcept)
import Control.Monad.Writer (runWriterT)
import Data.Bifunctor (bimap)
import Data.Maybe (fromJust)
import Language.Marlowe.Core.V1.Semantics.Types (Token(..))
import Language.Marlowe.Scripts -- (marloweValidatorBytes, marloweValidatorHash, rolePayoutValidatorBytes, rolePayoutValidatorHash)
import PlutusLedgerApi.V2
import PlutusCore.Evaluation.Machine.ExBudgetingDefaults (defaultCostModelParams)

import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Short as SBS
import qualified Data.Map.Strict as M


main :: IO ()
main =
  do
    putStrLn $ "Semantics validator hash:   " <> show marloweValidatorHash
    putStrLn $ "Role-payout validator hash: " <> show rolePayoutValidatorHash
    BS.writeFile "marlowe-semantics.plutus"
      $ "{\"type\": \"PlutusScriptV2\", \"description\": \"\", \"cborHex\": \""
      <> B16.encode (SBS.fromShort marloweValidatorBytes) <> "\"}"
    BS.writeFile "marlowe-rolepayout.plutus"
      $ "{\"type\": \"PlutusScriptV2\", \"description\": \"\", \"cborHex\": \""
      <> B16.encode (SBS.fromShort rolePayoutValidatorBytes) <> "\"}"
    print test


test :: Either String (LogOutput, Either EvaluationError ExBudget)
test =
  let
    roleToken = Token "" ""
    -- FIXME: Work in progress. Running this results in
    -- `Right ([],Left (IncompatibleVersionError (Version {_versionMajor = 1, _versionMinor = 1, _versionPatch = 0})))`
  in
    case evaluationContext of
     Left message -> Left message
     Right ec     -> Right
                       $ evaluateScriptCounting (ProtocolVersion 8 0) Verbose ec rolePayoutValidatorBytes
                       [toData roleToken, toData (), toData ScriptContext{..}] 


evaluationContext :: Either String EvaluationContext
evaluationContext =
  let
    costParams = M.elems $ fromJust defaultCostModelParams
    costModel = take (length ([minBound..maxBound] :: [ParamName])) costParams
  in
    bimap show fst . runExcept . runWriterT $ mkEvaluationContext costModel
