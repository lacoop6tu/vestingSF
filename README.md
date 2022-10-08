# Superfluid Foundry Starter Template

This is a foundry template for developing and testing Superfluid-related contracts such as Super
Tokens, Super Apps, and other contracts that call Superfluid agreements.

## Set Up

NOTE: You will need yarn (or npm) and foundry to use this project.

To get started, clone this repo:

```bash
git clone https://github.com/Fluid-X/superfluid_foundry_template
```

Next, install dependencies. At the time of writing, Superfluid _MUST_ be installed as node modules.

```bash
yarn
# Or `npm install` if you prefer npm
```

Next, try running the generic test:

```bash
forge test
```

## Project Layout

The majority of the project layout is as `forge init <name>` creates it. The main difference is the
node dependencies. For this, the `package.json` includes the Superfluid contracts. The
`foundry.toml` file contains has `node_modules` in the `libs` array, which tells the compiler where
to find dependencies. The `remappings.txt` file and the `.vscode` directory are for VSCode
compatibility on imports. You don't need this, but if you remove it, you'll get visual errors that
won't actually show up in tests.

## Set Up Tests

Import the `SuperfluidTester.sol` contract, then have your contract inherit it. In the constructor,
add `SuperfluidTester(admin)` where `admin` is the address you want to deploy with. For most tests,
this does not matter, so you can set it to `address(1)`.

```solidity
// omitting imports for brevity

contract YourTestContractNameHere is SuperfluidTester {

    // admin address
    address internal admin = address(1);

    // This deploys everything as `admin`
    constructor() SuperfluidTester(admin) {}

    // from here on, you can use `sf` to access everything.
    function setUp() public {
        // set up ...
    }

    // tests ...
}
```

## Using the `sf` Framework

The Superfluid Framework struct is defined as follows:

```solidity
struct Framework {
    TestGovernance governance;
    Superfluid host;
    ConstantFlowAgreementV1 cfa;
    CFAv1Library.InitData cfaLib;
    InstantDistributionAgreementV1 ida;
    IDAv1Library.InitData idaLib;
    SuperTokenFactory superTokenFactory;
}

// CFAv1Library
struct InitData {
    ISuperfluid host;
    IConstantFlowAgreementV1 cfa;
}

// IDAv1Library
struct InitData {
    ISuperfluid host;
    IInstantDistributionAgreementV1 ida;
}
```

### TestGovernance governance

This is for all things governance. Code updates, parameter tweaking, etc.

```solidity
// access TestGovernance
sf.goverance;

// get reward address example
sf.governance.getRewardAddress;
```

### Superfluid host

This is the monolithic Superfluid host contract. This handles agreements, apps, and callbacks.

```solidity
// access Superfluid
sf.host

// check if app is jailed example
sf.host.isAppJailed(app);
```

### ConstantFlowAgreementV1 cfa

This is the streaming agreement contract. This handles creating, updating, and deleting flows, as
well as flow operator permission updates and delegated flow handling.

```solidity
// access ConstantFlowAgreementV1
sf.cfa;

// createFlow example
sf.host.callAgreement(
    sf.cfa,
    abi.encodeCall(sf.cfa.createFlow, (token, receiver, flowRate, new bytes(0)),
    new bytes(0)
);
```

### CFAv1Library.InitData cfaLib

This is the CFA library. The `InitData` struct contains the Superfluid and ConstantFlowAgreementV1
interfaces. This is used for abstracting agreement calling. You can call CFA-related agreements
directly with this struct.

```solidity
// access CFAv1Library
sf.cfaLib;

// createFlow example
sf.cfaLib.createFlow(receiver, token, flowRate);
```

### InstantDistributionAgreementV1 ida

This is the distribution agreement contract. This handles creating indexes, distributing, and
subscriptions.

```solidity
// access InstantDistributionAgreementV1
sf.ida;

// createIndex example
sf.host.callAgreement(
    sf.ida,
    abi.encodeCall(sf.ida.createIndex, (token, indexId, new bytes(0))),
    new bytes(0)
);
```

### IDAv1Library.InitData idaLib

This is the IDA library. The `InitData` struct contains the Superfluid and
InstantDistributionAgreementV1 interfaces. This is used for abstracting agreement calling. You can
call IDA-related agreements directly with this struct.

```solidity
// access IDAv1Library
sf.idaLib;

// createIndex example
sf.idaLib.createIndex(token, indexId);
```

### SuperTokenFactory superTokenFactory

This is the super token factory contract. This handles creating, deploying, and updating super token
logic.

```solidity
// access SuperTokenFactory
sf.superTokenFactory;

// create pure super token contract
ISuperToken token = ISuperToken(sf.superTokenFactory.createSuperTokenLogic(sf.host));
token.initialize(underlyingERC20, underlyingDecimals, name, symbol);
```
