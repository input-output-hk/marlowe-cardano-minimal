-----------------------------------------------------------------------------
--
-- Module      :  $Headers
-- License     :  Apache 2.0
--
-- Stability   :  Experimental
-- Portability :  Portable
--
-- | Submitting Marlowe transactions.
--
-----------------------------------------------------------------------------


{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TupleSections     #-}


module Language.Marlowe.CLI.Transaction (
-- * Building
  buildSimple
, buildIncoming
, buildContinuing
, buildOutgoing
-- * Submitting
, submit
) where


import           Cardano.Api                                       (AddressAny, AddressInEra, AlonzoEra, AsType (..),
                                                                    BalancedTxBody (..), BuildTx, BuildTxWith (..),
                                                                    CardanoEra (..), CardanoMode,
                                                                    CollateralSupportedInEra (..),
                                                                    ConsensusModeIsMultiEra (..), CtxTx, EraInMode (..),
                                                                    ExecutionUnits (..), Hash, KeyWitnessInCtx (..),
                                                                    LocalNodeConnectInfo, MultiAssetSupportedInEra (..),
                                                                    PaymentKey, PlutusScript, PlutusScriptV1,
                                                                    PlutusScriptVersion (..), QueryInEra (..),
                                                                    QueryInMode (..), QueryInShelleyBasedEra (..),
                                                                    QueryUTxOFilter (..), ScriptDataSupportedInEra (..),
                                                                    ScriptDatum (..), ScriptLanguageInEra (..),
                                                                    ScriptWitness (..), ScriptWitnessInCtx (..),
                                                                    ShelleyBasedEra (..), ShelleyWitnessSigningKey (..),
                                                                    SlotNo, TxAuxScripts (..), TxBody (..),
                                                                    TxBodyContent (..), TxBodyErrorAutoBalance (..),
                                                                    TxCertificates (..), TxExtraKeyWitnesses (..),
                                                                    TxExtraKeyWitnessesSupportedInEra (..), TxFee (..),
                                                                    TxFeesExplicitInEra (..), TxId, TxIn, TxInMode (..),
                                                                    TxInsCollateral (..), TxMetadataInEra (..),
                                                                    TxMintValue (..), TxOut (..), TxOutDatum (..),
                                                                    TxOutValue (..), TxScriptValidity (..),
                                                                    TxUpdateProposal (..), TxValidityLowerBound (..),
                                                                    TxValidityUpperBound (..), TxWithdrawals (..),
                                                                    ValidityLowerBoundSupportedInEra (..),
                                                                    ValidityNoUpperBoundSupportedInEra (..),
                                                                    ValidityUpperBoundSupportedInEra (..), Value,
                                                                    WitCtxTxIn, Witness (..), anyAddressInEra,
                                                                    castVerificationKey, getTxId, getVerificationKey,
                                                                    hashScriptData, lovelaceToValue,
                                                                    makeTransactionBodyAutoBalance, queryNodeLocalState,
                                                                    readFileTextEnvelope, signShelleyTransaction,
                                                                    submitTxToNodeLocal, verificationKeyHash,
                                                                    writeFileTextEnvelope)
import           Cardano.Api.Shelley                               (fromPlutusData)
import           Control.Monad                                     ((<=<))
import           Control.Monad.Except                              (MonadError, MonadIO, liftIO, throwError)
import           Data.Maybe                                        (maybeToList)
import           Language.Marlowe.CLI.IO                           (decodeFileBuiltinData, readSigningKey)
import           Language.Marlowe.CLI.Types                        (CliError (..), PayFromScript (..), PayToScript (..),
                                                                    SomePaymentSigningKey, liftCli, liftCliIO)
import           Ouroboros.Network.Protocol.LocalTxSubmission.Type (SubmitResult (..))
import           Plutus.V1.Ledger.Api                              (Datum (..), Redeemer (..), toData)

import qualified Data.Set                                          as S (empty, fromList)


-- | Build a non-Marlowe transaction.
buildSimple :: MonadError CliError m
            => MonadIO m
            => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
            -> [TxIn]                            -- ^ The transaction inputs.
            -> [(AddressAny, Value)]             -- ^ The transaction outputs.
            -> AddressAny                        -- ^ The change address.
            -> FilePath                          -- ^ The output JSON file for the transaction body.
            -> m TxId                            -- ^ Action to build the transaction body.
buildSimple connection inputs outputs changeAddress bodyFile =
  do
    body <-
      buildBody connection
        Nothing
        Nothing
        inputs outputs Nothing changeAddress
        Nothing
        []
    liftCliIO
      $ writeFileTextEnvelope bodyFile Nothing body
    pure
      $ getTxId body


-- | Build a transaction paying into a Marlowe contract.
buildIncoming :: MonadError CliError m
              => MonadIO m
              => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
              -> AddressAny                        -- ^ The script address.
              -> FilePath                          -- ^ The file containing the datum for the payment to the script.
              -> Value                             -- ^ The value to be paid to the script.
              -> [TxIn]                            -- ^ The transaction inputs.
              -> [(AddressAny, Value)]             -- ^ The transaction outputs.
              -> AddressAny                        -- ^ The change address.
              -> FilePath                          -- ^ The output JSON file for the transaction body.
              -> m TxId                            -- ^ Action to build the transaction body.
buildIncoming connection scriptAddress outputDatumFile outputValue inputs outputs changeAddress bodyFile =
  do
    scriptAddress' <- asAlonzoAddress "Failed to converting script address to Alonzo era." scriptAddress
    outputDatum <- Datum <$> decodeFileBuiltinData outputDatumFile
    body <-
      buildBody connection
        Nothing
        (Just $ buildPayToScript scriptAddress' outputValue outputDatum)
        inputs outputs Nothing changeAddress
        Nothing
        []
    liftCliIO
      $ writeFileTextEnvelope bodyFile Nothing body
    pure
      $ getTxId body


-- | Build a transaction that spends from and pays to a Marlowe contract.
buildContinuing :: MonadError CliError m
                => MonadIO m
                => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
                -> AddressAny                        -- ^ The script address.
                -> FilePath                          -- ^ The file containing the script validator.
                -> FilePath                          -- ^ The file containing the redeemer.
                -> FilePath                          -- ^ The file containing the datum for spending from the script.
                -> [FilePath]                        -- ^ The files for required signing keys.
                -> TxIn                              -- ^ The script eUTxO to be spent.
                -> FilePath                          -- ^ The file containing the datum for the payment to the script.
                -> Value                             -- ^ The value to be paid to the script.
                -> [TxIn]                            -- ^ The transaction inputs.
                -> [(AddressAny, Value)]             -- ^ The transaction outputs.
                -> TxIn                              -- ^ The collateral.
                -> AddressAny                        -- ^ The change address.
                -> SlotNo                            -- ^ The first valid slot for the transaction.
                -> SlotNo                            -- ^ The last valid slot for the transaction.
                -> FilePath                          -- ^ The output JSON file for the transaction body.
                -> m TxId                            -- ^ Action to build the transaction body.
buildContinuing connection scriptAddress validatorFile redeemerFile inputDatumFile signingKeyFiles txIn outputDatumFile outputValue inputs outputs collateral changeAddress minimumSlot maximumSlot bodyFile =
  do
    scriptAddress' <- asAlonzoAddress "Failed to converting script address to Alonzo era." scriptAddress
    validator <- liftCliIO (readFileTextEnvelope (AsPlutusScript AsPlutusScriptV1) validatorFile)
    redeemer <- Redeemer <$> decodeFileBuiltinData redeemerFile
    inputDatum <- Datum <$> decodeFileBuiltinData inputDatumFile
    outputDatum <- Datum <$> decodeFileBuiltinData outputDatumFile
    keyHashes <- fmap hashSigningKey <$> mapM readSigningKey signingKeyFiles
    body <-
      buildBody connection
        (Just $ buildPayFromScript validator inputDatum redeemer txIn)
        (Just $ buildPayToScript scriptAddress' outputValue outputDatum)
        inputs outputs (Just collateral) changeAddress
        (Just (minimumSlot, maximumSlot))
        keyHashes
    liftCliIO
      $ writeFileTextEnvelope bodyFile Nothing body
    pure
      $ getTxId body


-- | Build a transaction spending from a Marlowe contract.
buildOutgoing :: MonadError CliError m
              => MonadIO m
              => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
              -> FilePath                          -- ^ The file containing the script validator.
              -> FilePath                          -- ^ The file containing the redeemer.
              -> FilePath                          -- ^ The file containing the datum for spending from the script.
              -> [FilePath]                        -- ^ The files for required signing keys.
              -> TxIn                              -- ^ The script eUTxO to be spent.
              -> [TxIn]                            -- ^ The transaction inputs.
              -> [(AddressAny, Value)]             -- ^ The transaction outputs.
              -> TxIn                              -- ^ The collateral.
              -> AddressAny                        -- ^ The change address.
              -> SlotNo                            -- ^ The first valid slot for the transaction.
              -> SlotNo                            -- ^ The last valid slot for the transaction.
              -> FilePath                          -- ^ The output JSON file for the transaction body.
              -> m TxId                            -- ^ Action to build the transaction body.
buildOutgoing connection validatorFile redeemerFile inputDatumFile signingKeyFiles txIn inputs outputs collateral changeAddress minimumSlot maximumSlot bodyFile =
  do
    validator <- liftCliIO (readFileTextEnvelope (AsPlutusScript AsPlutusScriptV1) validatorFile)
    redeemer <- Redeemer <$> decodeFileBuiltinData redeemerFile
    inputDatum <- Datum <$> decodeFileBuiltinData inputDatumFile
    keyHashes <- fmap hashSigningKey <$> mapM readSigningKey signingKeyFiles
    body <-
      buildBody connection
        (Just $ buildPayFromScript validator inputDatum redeemer txIn)
        Nothing
        inputs outputs (Just collateral) changeAddress
        (Just (minimumSlot, maximumSlot))
        keyHashes
    liftCliIO
      $ writeFileTextEnvelope bodyFile Nothing body
    pure
      $ getTxId body


-- | Collect information on paying from a script.
buildPayFromScript :: PlutusScript PlutusScriptV1  -- ^ The script.
                   -> Datum                        -- ^ The datum.
                   -> Redeemer                     -- ^ The redeemer.
                   -> TxIn                         -- ^ The eUTxO to be spent.
                   -> PayFromScript                -- ^ Payment information.
buildPayFromScript script datum redeemer txIn = PayFromScript{..}


-- | Collect information on paying to a script.
buildPayToScript :: AddressInEra era  -- ^ The script address.
                 -> Value             -- ^ The value to be paid.
                 -> Datum             -- ^ The datum.
                 -> PayToScript era   -- ^ The payment information.
buildPayToScript address value datum =
  let
    datumHash = hashScriptData . fromPlutusData $ toData datum
  in
    PayToScript{..}


-- | Hash a signing key.
hashSigningKey :: SomePaymentSigningKey  -- ^ The key.
               -> Hash PaymentKey        -- ^ The hash.
hashSigningKey =
  verificationKeyHash
    . either
        getVerificationKey
        (castVerificationKey . getVerificationKey)


-- | Build a balanced transaction body.
buildBody :: MonadError CliError m
          => MonadIO m
          => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
          -> Maybe PayFromScript               -- ^ Payment information from the script, if any.
          -> Maybe (PayToScript AlonzoEra)     -- ^ Payment information to the script, if any.
          -> [TxIn]                            -- ^ Transaction inputs.
          -> [(AddressAny, Value)]             -- ^ Transaction outputs.
          -> Maybe TxIn                        -- ^ Collateral, if any.
          -> AddressAny                        -- ^ The change address.
          -> Maybe (SlotNo, SlotNo)            -- ^ The valid slot range, if any.
          -> [Hash PaymentKey]                 -- ^ The extra required signatures.
          -> m (TxBody AlonzoEra)              -- ^ The action to build the transaction body.
buildBody connection payFromScript payToScript inputs outputs collateral changeAddress slotRange extraSigners =
  do
    changeAddress' <- asAlonzoAddress "Failed converting change address to Alonzo era." changeAddress
    start    <- queryAny    connection   QuerySystemStart
    history  <- queryAny    connection $ QueryEraHistory CardanoModeIsMultiEra
    protocol <- queryAlonzo connection   QueryProtocolParameters
    let
      txInsCollateral   = TxInsCollateral CollateralInAlonzoEra $ maybeToList collateral
      txFee             = TxFeeExplicit TxFeesExplicitInAlonzoEra 0
      txValidityRange   = (
                            maybe
                              TxValidityNoLowerBound
                              (TxValidityLowerBound ValidityLowerBoundInAlonzoEra . fst)
                              slotRange
                          , maybe
                              (TxValidityNoUpperBound ValidityNoUpperBoundInAlonzoEra)
                              (TxValidityUpperBound ValidityUpperBoundInAlonzoEra . snd)
                              slotRange
                          )
      txMetadata        = TxMetadataNone
      txAuxScripts      = TxAuxScriptsNone
      txExtraKeyWits    = TxExtraKeyWitnesses ExtraKeyWitnessesInAlonzoEra extraSigners
      txProtocolParams  = BuildTxWith $ Just protocol
      txWithdrawals     = TxWithdrawalsNone
      txCertificates    = TxCertificatesNone
      txUpdateProposal  = TxUpdateProposalNone
      txMintValue       = TxMintNone
      txScriptValidity  = TxScriptValidityNone
      scriptTxIn = maybe [] redeemScript payFromScript
      txIns = scriptTxIn <> fmap makeTxIn inputs
      scriptTxOut = maybe [] payScript payToScript
    txOuts <- (scriptTxOut <>) <$> mapM (uncurry makeTxOut) outputs
    utxo <-
      queryAlonzo connection
        . QueryUTxO
        . QueryUTxOByTxIn
        . S.fromList
        $ fst
        <$> txIns
    -- Compute the change.
    BalancedTxBody _ change _ <-
      liftCli
        $ makeTransactionBodyAutoBalance
            AlonzoEraInCardanoMode
            start
            history
            protocol
            S.empty
            utxo
            TxBodyContent{..}
            changeAddress'
            Nothing
    let
      -- Recompute execution units with full set of UTxOs, including change.
      trial =
        makeTransactionBodyAutoBalance
          AlonzoEraInCardanoMode
          start
          history
          protocol
          S.empty
          utxo
          (TxBodyContent{..} {txOuts = change : txOuts})
          changeAddress'
          Nothing
      -- Correct for a negative balance in cases where execution units, and hence fees, have increased.
      change' =
        case (change, trial) of
          (TxOut _ (TxOutValue _ value) _, Left (TxBodyErrorAdaBalanceNegative delta)) -> TxOut
                                                                                            changeAddress'
                                                                                            (
                                                                                              TxOutValue MultiAssetInAlonzoEra
                                                                                                $ value <> lovelaceToValue delta
                                                                                            )
                                                                                            TxOutDatumNone
          _                                                                            -> change
    -- Construct the body with correct execution units and fees.
    BalancedTxBody txBody _ _ <-
      liftCli
        $ makeTransactionBodyAutoBalance
            AlonzoEraInCardanoMode
            start
            history
            protocol
            S.empty
            utxo
            (TxBodyContent{..} {txOuts = change' : txOuts})
            changeAddress'
            Nothing
    return txBody


-- | Sign and submit a transaction.
submit :: MonadError CliError m
       => MonadIO m
       => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
       -> FilePath                          -- ^ The transaction body file.
       -> [FilePath]                        -- ^ The signing key files.
       -> m TxId                            -- ^ The action to submit the transaction.
submit connection bodyFile signingKeyFiles =
  do
    body <- liftCliIO $ readFileTextEnvelope (AsTxBody AsAlonzoEra) bodyFile
    signings <- mapM readSigningKey signingKeyFiles
    submitBody connection body signings


-- | Sign and submit a transaction.
submitBody :: MonadError CliError m
           => MonadIO m
           => LocalNodeConnectInfo CardanoMode  -- ^ The connection info for the local node.
           -> TxBody AlonzoEra                  -- ^ The transaction body.
           -> [SomePaymentSigningKey]           -- ^ The signing keys.
           -> m TxId                            -- ^ The action to submit the transaction.
submitBody connection body signings =
  do
    let
      tx =
        signShelleyTransaction body
          $ either WitnessPaymentKey WitnessPaymentExtendedKey
          <$> signings
    result <-
      liftIO
        . submitTxToNodeLocal connection
        $ TxInMode tx AlonzoEraInCardanoMode
    case result of
      SubmitSuccess     -> pure $ getTxId body
      SubmitFail reason -> throwError . CliError $ show reason


-- | Compute the transaction input for paying from a script.
redeemScript :: PayFromScript                                                 -- ^ The payment information.
             -> [(TxIn, BuildTxWith BuildTx (Witness WitCtxTxIn AlonzoEra))]  -- ^ The transaction input.
redeemScript PayFromScript{..} =
  [
    (
      txIn
    , BuildTxWith
        . ScriptWitness ScriptWitnessForSpending
        $ PlutusScriptWitness
          PlutusScriptV1InAlonzo
          PlutusScriptV1
          script
          (ScriptDatumForTxIn . fromPlutusData $ toData datum)
          (fromPlutusData $ toData redeemer)
          (ExecutionUnits 0 0)
    )
  ]


-- | Compute the transaction output for paying to a script.
payScript :: PayToScript AlonzoEra  -- ^ The payment information.
          -> [TxOut CtxTx AlonzoEra]      -- ^ The transaction input.
payScript PayToScript{..} =
  [
    TxOut
      address
      (TxOutValue MultiAssetInAlonzoEra value)
      (TxOutDatumHash ScriptDataInAlonzoEra datumHash)
  ]


-- | Compute transaction input for building a transaction.
makeTxIn :: TxIn                                                        -- ^ The transaction input.
         -> (TxIn, BuildTxWith BuildTx (Witness WitCtxTxIn AlonzoEra))  -- ^ The building for the transaction input.
makeTxIn = (, BuildTxWith $ KeyWitness KeyWitnessForSpending)


-- | Compute transaction output for building a transaction.
makeTxOut :: MonadError CliError m
          => AddressAny           -- ^ The output address.
          -> Value                -- ^ The output value.
          -> m (TxOut CtxTx AlonzoEra)  -- ^ Action for building the transaction output.
makeTxOut address value =
  do
    address' <- asAlonzoAddress "Failed converting output address to Alonzo era." address
    pure
      $ TxOut
        address'
        (TxOutValue MultiAssetInAlonzoEra value)
        TxOutDatumNone


-- | Convert an address to Alonzo era.
asAlonzoAddress :: MonadError CliError m
                => String                     -- ^ The error message.
                -> AddressAny                 -- ^ The address.
                -> m (AddressInEra AlonzoEra) -- ^ Action for converting the address.
asAlonzoAddress message =
  liftCli
    . maybe (Left message) Right
    . anyAddressInEra AlonzoEra


-- | Query a node.
queryAny :: MonadError CliError m
         => MonadIO m
         => LocalNodeConnectInfo CardanoMode -- ^ The connection info for the local node.
         -> QueryInMode CardanoMode a        -- ^ The query.
         -> m a                              -- ^ Action for running the query.
queryAny connection =
 liftCliIO
   . queryNodeLocalState connection Nothing


-- | Query an Alonzo-era node.
queryAlonzo :: MonadError CliError m
            => MonadIO m
            => LocalNodeConnectInfo CardanoMode   -- ^ The connection info for the local node.
            -> QueryInShelleyBasedEra AlonzoEra a -- ^ The query.
            -> m a                                -- ^ Action for running the query.
queryAlonzo connection =
  liftCli
    <=< (
          liftCliIO
          . queryNodeLocalState connection Nothing
          . QueryInEra AlonzoEraInCardanoMode
          . QueryInShelleyBasedEra ShelleyBasedEraAlonzo
        )
