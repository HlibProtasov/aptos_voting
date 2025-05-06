module voting::vote {
    use std::string::String;
    use std::vector;
    use std::table::{Table, Self};
    use std::signer;
    use std::timestamp;
    use aptos_framework::object::{Object, Self};


    const EAlreadyExists: u64 = 0;
    const ENotExists: u64 = 1;
    const EWrongSigner: u64 = 2;
    const EAlreadyVoted: u64 = 3;
    const EVotingFinished: u64 = 4;
    const EWrongData: u64 = 5;
    const EInProgress: u64 = 6;

    const VotingProgramSeeds: vector<u8> = b"VotingProgramSeeds";

    struct Voting has key, store {
        name: String,
        candidates: vector<String>,
        endTimeInSec: u64,
        votingUsers: Table<address, bool>,
        votingResult: Table<u64, u64> //Candidate index to votes
    }

    struct VotingProgram has key {
        votings: Table<u64, Voting>,
        votingId: u64

    }
    public entry fun init(creator: &signer) {
        let addr = signer::address_of(creator);
        assert!(!exists<VotingProgram>(addr), EAlreadyExists);
        assert!(addr == @voting, EWrongSigner);
        let constructor_ref =  object::create_named_object(creator, VotingProgramSeeds);

        let object_signer = object::generate_signer(&constructor_ref);
        let voting_program = VotingProgram {
            votings: table::new(),
            votingId: 0
        };
        move_to(&object_signer, voting_program);

    }

    public entry fun create_voting(creator: &signer, obj: Object<VotingProgram> ,name: String, candidates: vector<String>, endTimeInSec: u64) acquires VotingProgram {
        let addr = signer::address_of(creator);

        assert!(object::owner(obj) == addr, EWrongSigner);
        assert!(endTimeInSec > timestamp::now_seconds(), EWrongData);
        let program_address = object::object_address(&obj);       

        let voting_program = &mut VotingProgram[program_address];
        voting_program.votingId += 1;

        let voting = Voting {
        name,
        candidates,
        endTimeInSec,
        votingUsers: table::new(),
        votingResult: table::new()
        };
        table::add(&mut voting_program.votings, voting_program.votingId, voting);

  }
        public entry fun vote(caller: &signer, obj: Object<VotingProgram>, votingId: u64, candidateId: u64) acquires VotingProgram {
            let caller_addr = signer::address_of(caller);
            let program_address = object::object_address(&obj);
            let voting_program = borrow_global_mut<VotingProgram>(program_address);
            
            assert!(voting_program.votingId >= votingId, ENotExists);
           
           let voting_ref = table::borrow_mut(&mut voting_program.votings, votingId);
           if(!table::contains(&mut voting_ref.votingUsers, caller_addr)) {
                table::add(&mut voting_ref.votingUsers, caller_addr, false);
           };
           let voted = table::borrow_mut(&mut voting_ref.votingUsers, caller_addr);

           assert!(voting_ref.endTimeInSec >= timestamp::now_seconds(), EVotingFinished);
           assert!(!*voted, EAlreadyVoted);
           assert!(((vector::length(&voting_ref.candidates) - 1)  >= candidateId), EWrongData);

            if(!table::contains(&mut voting_ref.votingResult, candidateId)) {
                table::add(&mut voting_ref.votingResult, candidateId, 0);
           };
           let votedResult = table::borrow_mut(&mut voting_ref.votingResult, candidateId);

           *votedResult += 1;
           *voted = true;
        }


        // The case where multiple candidates have the same result is not handled
        //  the first candidate is selected as the winner due to lack of specification in the task.
        public fun get_winner(votingId: u64, obj: Object<VotingProgram>): String acquires VotingProgram {
            let program_address = object::object_address(&obj);
            let voting_program = borrow_global<VotingProgram>(program_address);

             assert!(voting_program.votingId >= votingId, ENotExists);

            let voting_ref = table::borrow(&voting_program.votings, votingId);
            assert!(voting_ref.endTimeInSec <= timestamp::now_seconds(), EInProgress);
            let maxVoutes = 0;
            let winner_index = 0;
            let candidates = vector::length(&voting_ref.candidates) - 1;
            for(v in 0..candidates) {
                
            if(!table::contains(&voting_ref.votingResult, v)) {
                    continue;
            };
            let candidate_result = table::borrow(&voting_ref.votingResult, v);
            if(*candidate_result > maxVoutes)
              maxVoutes = maxVoutes;
              winner_index = v;
            };

           *vector::borrow(&voting_ref.candidates, winner_index)
        }


        // Gives the possibility to create a voting for the receiver
        public entry fun transfer_ownership(caller: &signer, obj: Object<VotingProgram>, receiver: address) {
              let addr = signer::address_of(caller);

             assert!(object::owner(obj) == addr, EWrongSigner);

             object::transfer(caller, obj, receiver);
        }

        #[test(creator = @voting)]
        fun init_test(creator: signer) {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
       
        }

        #[test_only]
        use std::string::utf8;
        #[test(creator = @voting,framework = @0x1)]
        fun create_voting_test(creator: signer, framework: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            
            let program = borrow_global<VotingProgram>(object_address);
            
            assert!(program.votingId == 1);

    }

      
        #[test(creator = @voting,framework = @0x1, new_owner = @0x012414)]
        fun create_voting_after_transfer_ownership_test(creator: signer, framework: signer, new_owner: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            



            transfer_ownership(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                signer::address_of(&new_owner)
                );

                create_voting(
                &new_owner,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );

            let program = borrow_global<VotingProgram>(object_address);
            
            assert!(program.votingId == 2);


            vote(&creator, object::address_to_object<VotingProgram>(object_address), 2, 1);

            let program = borrow_global<VotingProgram>(object_address);
            let voting = table::borrow(&program.votings, 2);
            let user_voted = table::borrow(&voting.votingUsers, signer::address_of(&creator));

            assert!(*user_voted); 

            let user_voted = table::borrow(&voting.votingResult, 1);

            assert!(user_voted == &1)

    }


    
        #[test(creator = @voting, framework = @0x1, wrong_creator = @0x01241)]
        #[expected_failure(abort_code = EWrongSigner)]
        fun create_init_with_wrong_creator_test(creator: signer, framework: signer, wrong_creator: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &wrong_creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            
    }



        #[test(creator = @voting,framework = @0x1,voter = @0x02)]
        fun vote_test(creator: signer, framework: signer, voter: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            

            vote(&voter, object::address_to_object<VotingProgram>(object_address), 1, 1);

            let program = borrow_global<VotingProgram>(object_address);
            let voting = table::borrow(&program.votings, 1);
            let user_voted = table::borrow(&voting.votingUsers, signer::address_of(&voter));

            assert!(*user_voted); 

            let user_voted = table::borrow(&voting.votingResult, 1);

            assert!(user_voted == &1)

    }

        #[test(creator = @voting,framework = @0x1,voter = @0x02)]
        #[expected_failure(abort_code = EAlreadyVoted)]
        fun vote_only_once_test(creator: signer, framework: signer, voter: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            

            vote(&voter, object::address_to_object<VotingProgram>(object_address), 1, 1);
            vote(&voter, object::address_to_object<VotingProgram>(object_address), 1, 2);

    }

        #[test(creator = @voting,framework = @0x1,voter = @0x02)]
        #[expected_failure(abort_code = EVotingFinished)]
        fun can_not_vote_after_the_end(creator: signer, framework: signer, voter: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            
            std::timestamp::update_global_time_for_test_secs(endTime + 100);
            vote(&voter, object::address_to_object<VotingProgram>(object_address), 1, 1);

    }


        #[test(creator = @voting,framework = @0x1,voter = @0x02, voter2 = @0x03, voter3 = @0x04)]
        fun happy_case(creator: signer, framework: signer, voter: signer, voter2: signer, voter3: signer) acquires VotingProgram {
            init(&creator);
            let object_address = object::create_object_address(&signer::address_of(&creator), VotingProgramSeeds);
            assert!(exists<VotingProgram>(object_address));
            std::timestamp::set_time_has_started_for_testing(&framework);
            let endTime = std::timestamp::now_seconds() + 86400;
            create_voting(
                &creator,
                object::address_to_object<VotingProgram>(object_address),
                utf8(b"MyVoting"),
                vector[utf8(b"1"), utf8(b"2"), utf8(b"3")],
                endTime 
                );
            

            vote(&voter, object::address_to_object<VotingProgram>(object_address), 1, 1);
            vote(&voter2, object::address_to_object<VotingProgram>(object_address), 1, 2);
            vote(&voter3, object::address_to_object<VotingProgram>(object_address), 1, 2);

            std::timestamp::update_global_time_for_test_secs(endTime + 100);
            let winner = get_winner(1, object::address_to_object<VotingProgram>(object_address));

            assert!(winner == utf8(b"2"));

    }


}