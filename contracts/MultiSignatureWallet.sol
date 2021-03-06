pragma solidity ^0.4.25;

contract MultiSignatureWallet {
    
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);

    address[] public owners;
    uint public required;
    mapping (address => bool) public isOwner;
    
    struct Transaction {
      bool executed;
      address destination;
      uint value;
      bytes data;
    }
    
    mapping (uint => mapping (address => bool)) public confirmations;
    
    uint public transactionCount;
    mapping (uint => Transaction) public transactions;

    modifier validRequirement(uint ownerCount, uint _required) {
        if (   _required > ownerCount
            || _required == 0
            || ownerCount == 0)
            revert();
        _;
    }
    
    /// @dev Fallback function, which accepts ether when sent to contract
    function() external payable {}

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public validRequirement(_owners.length, _required)
    {
        for (uint i=0; i<_owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data) public returns (uint transactionId) {
        require(isOwner[msg.sender]);
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != 0);
        require(confirmations[transactionId][msg.sender] == false);
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    //function revokeConfirmation(uint transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        if (isConfirmed(transactionId)) {
            Transaction storage execTxn = transactions[transactionId];
            execTxn.executed = true;
            if (execTxn.destination.call.value(execTxn.value)(execTxn.data))
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                execTxn.executed = false;
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        uint count = 0;
        for (uint i=0; i<owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }
}
