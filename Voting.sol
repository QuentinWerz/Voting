// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

//OZ imports
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

//local imports (none)

//Notes :
// - Owner has to register if wants to see proposals and vote counts. If not, can still drive the process without seeing inside.
// - Workflow status is incremented. Means that no backward possible and only one voting session per contract deployement.
// - Votes saved can't be changed.
// - Default winning proposal (0 votes case) is the first that was proposed. Idem in case of equality.

contract Voting is Ownable, Pausable {

        struct Voter {
            bool isRegistered;
            bool hasVoted;
            uint8 votedProposalId;
        }

        mapping(address=> Voter) voters;

        struct Proposal {
            string description;
            uint8 voteCount;
        }

        Proposal[] proposals;

        enum WorkflowStatus {
            RegisteringVoters,
            ProposalsRegistrationStarted,
            ProposalsRegistrationEnded,
            VotingSessionStarted,
            VotingSessionEnded,
            VotesTallied
        }
        WorkflowStatus public state = WorkflowStatus.RegisteringVoters;

        event VoterRegistered(address voterAddress); 
        event WorkflowStatusChange(uint8 previousStatus, uint8 newStatus);
        event ProposalRegistered(uint8 proposalId);
        event Voted(address voter, uint8 proposalId);

        uint8 winningProposalId; 

    //modifiers////////////////////
        //voter
        modifier checkRegistered() {
            require(voters[msg.sender].isRegistered == true, "You're not registered yet.");
            _;
        }

        modifier checkVoted() {
            require(voters[msg.sender].hasVoted == false, "Already voted !");
            _;
        }

        modifier checkTargetRegistered(address _address) { // case when targeted address is not registered
            require(voters[_address].isRegistered == true, "Unknown address.");
            _;
        }
        //proposal
        modifier proposalExists(uint _proposalId) {
            require(proposals.length > 0 && _proposalId <= proposals.length - 1 && _proposalId >= 0, "Invalid Proposal ID or no proposals yet.");
            _;
        }
        //workflow status
        modifier whenRegisterationOpen() {
            require(uint8(state) == 0, "Registeration closed.");
            _;
        }

        modifier whenProposalRegisterationOpen() {
            require(uint8(state) == 1, "Proposal registeration closed.");
            _;
        }

        modifier whenVotingSessionOpen() {
            require(uint8(state) == 3, "Voting session closed.");
            _;
        }

        modifier afterVotingOpening() {
            require(uint8(state) >= 3, "Wait until voting session is open.");
            _;
        }

        modifier whenVotesTallied() {
            require(uint8(state) >= 5, "Cannot see the winner yet.");
            _;
        }
    ////////////////////////////////

    //change Status ///////////////
        function changeStatus() external onlyOwner whenNotPaused {
            require(uint8(state) < 5, "Voting process ended.");
            uint8 previousStatus = uint8(state);
            state = WorkflowStatus(previousStatus+1);
            emit WorkflowStatusChange(previousStatus, uint8(state));
        }
    ///////////////////////////////

    //register a voter//////////////
        function register(address _address) external onlyOwner whenRegisterationOpen whenNotPaused {
            voters[_address].isRegistered = true;
            emit VoterRegistered(_address);
        }

    //get Voter infos /////////////
        function getVoterRegistered(address _address) external view checkRegistered checkTargetRegistered(_address) returns (bool) {
            return voters[_address].isRegistered;
        }
        function getVoterVoted(address _address) external view checkRegistered afterVotingOpening checkTargetRegistered(_address) returns (bool) { 
            return voters[_address].hasVoted;
        }
            function getVoterProposalVoted(address _address) external view checkRegistered afterVotingOpening checkTargetRegistered(_address) returns (uint8) {
            return voters[_address].votedProposalId;
        }
    ////////////////////////////////

    //send a Proposal//////////////////
        function propose(string memory _proposal) external checkRegistered whenProposalRegisterationOpen whenNotPaused {
            require(keccak256(abi.encodePacked(_proposal)) != keccak256(abi.encodePacked("")), "Enter a clear and understandable proposal.");
            proposals.push(Proposal(_proposal, 0));
            emit ProposalRegistered(uint8(proposals.length) - 1);
        }
    ///////////////////////////////

    //see a proposal///////////////
        function getProposalDescription(uint8 _proposalId) external view checkRegistered proposalExists(_proposalId) returns (string memory) {
            return proposals[_proposalId].description;
        }
        function getProposalVoteCount(uint8 _proposalId) external view checkRegistered afterVotingOpening proposalExists(_proposalId) returns (uint8) {
            return proposals[_proposalId].voteCount;
        }
    ///////////////////////////////

    //save a Vote//////////////////
        function vote(uint8 _proposalId) external checkRegistered whenVotingSessionOpen checkVoted proposalExists(_proposalId) whenNotPaused {
            require(_proposalId <= proposals.length - 1 && _proposalId >= 0, "Please select an existing Proposal ID.");
            proposals[_proposalId].voteCount++;
            voters[msg.sender].votedProposalId = _proposalId;
            voters[msg.sender].hasVoted = true;
            emit Voted(msg.sender, _proposalId);
        }
    ///////////////////////////////

    // nominate winner (first proposal with higher rate is selected)
        function checkWinner() external onlyOwner whenVotesTallied returns (uint8) {
            uint8 greaterNumber;
            for (uint8 i = 1 ; i < proposals.length ; i++) {
                if(proposals[i].voteCount > proposals[i-1].voteCount) {
                    greaterNumber = proposals[i].voteCount;
                    } else {
                    greaterNumber = proposals[i-1].voteCount;
                    }
            }

            for (uint8 i = 0 ; i < proposals.length ; i++) {
                if(proposals[i].voteCount == greaterNumber) {
                    winningProposalId = i;
                    return winningProposalId;                    
                }
            }
            return winningProposalId;              
        }
    ///////////////////////////////

    // get the winner
        function getWinner() external view whenVotesTallied checkRegistered returns (uint8) {
            return winningProposalId;
        } 

    // Withdraw & receive
        function withdraw() external onlyOwner whenNotPaused payable {
                (bool success,) = owner().call{value: address(this).balance}("");
                require(success, "Transfer failed.");
        }

        receive() external whenNotPaused payable {
            //
        }
}