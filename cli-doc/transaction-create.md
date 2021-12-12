# Marlowe CLI: Build a Transaction that Pays to a Marlowe Contract

The `transaction-create` command builds a transaction that pays to a Marlowe contract. This command can be used to initially fund a Marlowe contract.


## Usage

    $ marlowe-cli transaction-create --help
    
    Usage: marlowe-cli transaction-create [--testnet-magic INTEGER]
                                          --socket-path SOCKET_FILE
                                          --script-address ADDRESS
                                          [--required-signer SIGNING_FILE]
                                          --tx-out-datum-file DATUM_FILE
                                          --tx-out-value LOVELACE
                                          [--tx-in TXID#TXIX]
                                          [--tx-out ADDRESS+VALUE]
                                          --change-address ADDRESS --out-file FILE
                                          [--submit SECONDS] [--print-stats]
      Build a transaction that pays to a Marlowe script.
    
    Available options:
      --testnet-magic INTEGER         Network magic, or omit for mainnet.
      --socket-path SOCKET_FILE       Location of the cardano-node socket file.
      --script-address ADDRESS        Address of the Marlowe contract.
      --required-signer SIGNING_FILE  Files containing required signing keys.
      --tx-out-datum-file DATUM_FILE  Datum JSON file datum paid to Marlowe contract.
      --tx-out-value LOVELACE         Lovelace value paid to Marlowe contract.
      --tx-in TXID#TXIX               Transaction input in TxId#TxIx format.
      --tx-out ADDRESS+VALUE          Transaction output in ADDRESS+VALUE format.
      --change-address ADDRESS        Address to receive ADA in excess of fee.
      --out-file FILE                 Output file for transaction body.
      --submit SECONDS                Also submit the transaction, and wait for confirmation.
      --print-stats                   Print statistics.
      -h,--help                       Show this help text


## Example

See [extended-tutorial.md](extended-tutorial.md).
