pragma solidity ^0.8.7;

import "hardhat/console.sol";

enum FrequencyMultiplier {
    NONE,
    DAY,
    WEEK,
    MONTH,
    YEAR
}

contract ReceiptContract {

    struct Entity {
        address ad;
        string name;
        string company;
        string idCode; /* CPF/CNPJ */
    }

    struct Date {
        uint8 day;
        uint8 month;
        uint16 year;

        uint8 hour;
        uint8 minute;
    }

    struct Receipt {
        Entity sender;
        Entity receiver;
        uint value; /* amount of wei (ether / 1e18) */
        string reason;
        uint frequencyInstallment; /* FREQUENCY if isRecurrent is true else INSTALLMENT */
        uint duration;
        FrequencyMultiplier frequencyMultiplier;
        bool isRecurrent;
        bool isFulfilled;
        string fulfillmentCriteria;
        Date createAt; /* date */

        /* PRIVATE */
        uint storedValue;
        uint currentInstallment;
        bool isRedeemable;
        Date lastUpdatedAt;
    }

    uint receiptsCount = 0;

    mapping(uint => Receipt) receipts;
    mapping(uint => Entity) senders;
    mapping(uint => Entity) receivers;
    mapping(uint => Date) dates;

    function setSender(        
        string memory _sname, 
        string memory _scompany, 
        string memory _sidCode
    ) public {
        Entity storage sender = senders[receiptsCount];
        sender.ad = msg.sender;
        sender.name = _sname;
        sender.company = _scompany;
        sender.idCode = _sidCode;
    }

    function setReceiver(        
        address _raddress, 
        string memory _rname, 
        string memory _rcompany, 
        string memory _ridCode
    ) public {
        Entity storage receiver = receivers[receiptsCount];
        receiver.ad = _raddress;
        receiver.name = _rname;
        receiver.company = _rcompany;
        receiver.idCode = _ridCode;
    }

    function setDate(uint8 day, uint8 month, uint16 year, uint8 hour, uint8 minute) public {
        Date storage date = dates[receiptsCount];
        date.day = day;
        date.month = month;
        date.year = year;
        date.hour = hour;
        date.minute = minute;
    }


    function addReceipt
    (
        address payable sender,
        uint _value, 
        string memory _reason, 
        uint _frequencyInstallment,
         uint _duration,
        FrequencyMultiplier _frequencyMultiplier, 
        bool _isRecurrent, 
        string memory _fulfillmentCriteria
    ) 
    public 
    payable 
    returns (bool, string memory, int) 
    {
        if (msg.value != _value) {
            sender.transfer(msg.value);
            return (false, "Informed value does not correspond to sent in the message", -1);
        }

        Receipt memory receipt = receipts[receiptsCount];
        receipt.sender = senders[receiptsCount];
        receipt.receiver = receivers[receiptsCount];
        receipt.value = _value;
        receipt.reason = _reason;
        receipt.frequencyInstallment = _frequencyInstallment;
        receipt.frequencyMultiplier = _frequencyMultiplier;
        receipt.duration = _duration;
        receipt.isRecurrent = _isRecurrent;
        receipt.isFulfilled = _value == 0;
        receipt.fulfillmentCriteria = _fulfillmentCriteria;
        receipt.createAt = dates[receiptsCount];
        receipt.storedValue = _value;
        receipt.currentInstallment = 0;
        receipt.isRedeemable = false;

        receiptsCount++;

        return (true, "Success!", int(receiptsCount - 1));
    }

    function lock(uint index) public returns (bool, string memory) {
        if (index >= receiptsCount) {
            return (false, "Index is not valid");
        }

        if (msg.sender != senders[index].ad) {
            /* ONLY THE CREATOR OF THE RECEIPT CAN LOCK THE RECEIPT */
            return (false, "Sender not valid");
        }

        Receipt storage receipt = receipts[index];
        if (receipt.isFulfilled) {
            return (false, "Receipt is already fulfilled");
        } else {
            receipt.isRedeemable = false;
            return (true, "Success!");
        }
    }

    function unlock(uint index) public returns (bool) {
        if (index >= receiptsCount) {
            return false;
        }

        if (msg.sender != senders[index].ad) {
            /* ONLY THE CREATOR OF THE RECEIPT CAN UNLOCK THE RECEIPT */
            return false;
        }

        Receipt storage receipt = receipts[index];
        if (receipt.isFulfilled) {
            return false;
        } else {
            receipt.isRedeemable = true;
            return true;
        }
    }

    function redeem(uint index, address payable _to) public returns (bool, string memory) {
        if (index >= receiptsCount) {
            return (false, "Index not valid");
        }

        if (_to != receivers[index].ad) {
            /* ONLY THE RECEIVER OF THE RECEIPT CAN REDEEM SOME VALUE */
            return (false, "Receiver not valid");
        }

        Receipt storage receipt = receipts[index];

        if (receipt.isFulfilled) {
            return (false, "Receipt is already fulfilled");
        }

        if (!receipt.isRedeemable) {
            return (false, "Receipt is not redeemable");
        }

        if (receipt.isRecurrent) {
            receipt.currentInstallment += receipt.frequencyInstallment;
            _to.transfer(receipt.storedValue);
            if (receipt.currentInstallment >= receipt.duration) {
                receipt.isFulfilled = true;
                return (true, "Redeem Successful, Receipt is now fulfilled");
            }
        } else {
            uint installmentValue = receipt.value / receipt.frequencyInstallment;
            if (++receipt.currentInstallment < receipt.frequencyInstallment && installmentValue <= receipt.storedValue) {
                _to.transfer(installmentValue);
            } else {
                _to.transfer(receipt.storedValue);
                receipt.isFulfilled = true;
                return (true, "Redeem Successful, Receipt is now fulfilled");
            }
        }

        receipt.isRedeemable = false;

        return (true, "Redeem Successful");
    }

    function addFunds(address payable sender, uint index) public payable returns (bool) {
        if (index >= receiptsCount) {
            sender.transfer(msg.value);
            return false;
        }

        if (msg.sender != senders[index].ad) {
            /* ONLY THE CREATOR OF THE RECEIPT CAN ADD FUNDS */
            sender.transfer(msg.value);
            return false;
        }

        Receipt memory receipt = receipts[index];

        if (receipt.isFulfilled) {
            sender.transfer(msg.value);
            return false;
        }

        if (receipt.isRecurrent) {
            receipt.storedValue += msg.value;
        } else {
            sender.transfer(msg.value);
            return false;
        }

        receipts[index] = receipt;

        return true;
    }

    function getReceipt(uint index) public view returns (bool, Receipt memory) {
        if (index >= receiptsCount) {
            revert("Not Found");
        }

        return (true, receipts[index]);
    }

    function clearContract() public {
        receiptsCount = 0;
    }
}