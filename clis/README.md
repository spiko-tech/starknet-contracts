### Craft token contract deployment call data

You can generate the call data of the token deployment like that:

```bash
node dist/main.js craft-token-contract-deployment --address ADDRESS --environment ENVIRONMENT
```

Then you can use it in the `sncast deploy --url RPC --class-hash CLASS_HASH --constructor-calldata CALL_DATA` command.
