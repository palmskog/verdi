Require Import Arith.
Require Import List.
Import ListNotations.

Require Import Util.
Require Import Net.
Require Import RaftState.
Require Import Raft.
Require Import VerdiTactics.

Require Import RaftMsgRefinementInterface.

Section GhostLogCorrectInterface.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Definition ghost_log_correct net :=
    forall p l t leaderId prevLogIndex prevLogTerm entries leaderCommit,
      In p (nwPackets net) ->
      snd (pBody p) = AppendEntries t leaderId prevLogIndex prevLogTerm
                                    entries leaderCommit ->
      fst (pBody p) = l ->
      (prevLogIndex = 0 /\ prevLogTerm = 0 /\ Prefix entries l) \/
      (exists e,
         eIndex e = prevLogIndex /\
         eTerm e = prevLogTerm /\
         In e l) /\
      Prefix entries (findGtIndex l prevLogIndex).


  Class ghost_log_correct_interface : Prop :=
    {
      ghost_log_correct_invariant :
        forall net,
          msg_refined_raft_intermediate_reachable net ->
          ghost_log_correct net
    }.
  
End GhostLogCorrectInterface.