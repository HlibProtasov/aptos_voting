# Voting Contract on Aptos

## Description

This smart contract allows users to create and participate in votings on the Aptos blockchain. A voting event lasts for a specified time period, after which the winner can be determined. The admin (initial deployer) also has the ability to transfer the right to create new votings to another user.

---

## Functions

### `init`
Initializes the contract.  
Must be called **once after deployment** by the contract deployer.

### `create_voting`
Creates a new voting instance.  
Can only be called by the **owner** of the Voting contract (by default, the contract deployer).

### `vote`
Allows a user to vote for one of the candidates.  
Each user can vote **only once per voting**.

### `get_winner`
Returns the winner of the voting.  
Can be called **by anyone** after the voting period ends.

### `transfer_ownership`
Transfers the ownership (the right to create votings) to another user.  
Can only be called by the **current owner**.

---

## Notes

- Only one vote per user per voting is allowed.
- Voting creation rights can be passed from the current owner to another address.
