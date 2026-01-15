
```
┌─────────────────────────────────────────────────────────────┐
│                        USER FRONTEND                         │
│  • Holds private data (amounts, collateral details)         │
│  • Generates commitments (hashes)                           │
│  • Sends private data to Proof Service                      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ Private inputs + Public inputs
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              PROOF SERVICE (Backend             │
│  ✓ Generates ZK proofs using SP1                           │
│  ✓ Takes private inputs (actual values)                    │
│  ✓ Produces: proof + public signals                        │
│  ✓ Never stores private data                               │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ Proof + Public signals
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                PRIVACY MODULE (Smart Contract)              │
│  ✓ Verifies proofs on-chain                                │
│  ✓ Checks commitments match                                │
│  ✓ Tracks nullifiers (prevents double-spend)               │
│  ✓ Never sees private data                                 │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ Verified ✓
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                  LOAN CORE (Smart Contract)                 │
│  ✓ Executes loan after privacy verification                │
│  ✓ Stores only commitments (not actual values)             │
│  ✓ Respects privacy settings per loan                      │
└─────────────────────────────────────────────────────────────┘
```