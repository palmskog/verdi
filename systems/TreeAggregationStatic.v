Require Import Verdi.
Require Import HandlerMonad.
Require Import NameOverlay.

Require Import TotalMapSimulations.
Require Import PartialMapSimulations.
Require Import PartialExtendedMapSimulations.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Require Import Sumbool.

Require Import mathcomp.ssreflect.ssreflect.
Require Import mathcomp.ssreflect.ssrbool.
Require Import mathcomp.ssreflect.eqtype.
Require Import mathcomp.ssreflect.fintype.
Require Import mathcomp.ssreflect.finset.
Require Import mathcomp.fingroup.fingroup.

Require Import Orders.
Require Import MSetFacts.
Require Import MSetProperties.

Require Import Sorting.Permutation.

Require Import AAC_tactics.AAC.

Require Import AggregationAux.
Require Import AggregationStatic.

Require Import TreeAux.
Require Import TreeStatic.

Set Implicit Arguments.

Module TreeAggregation (Import NT : NameType)  
 (NOT : NameOrderedType NT) (NSet : MSetInterface.S with Module E := NOT) 
 (NOTC : NameOrderedTypeCompat NT) (NMap : FMapInterface.S with Module E := NOTC) 
 (Import RNT : RootNameType NT) (Import CFG : CommutativeFinGroup) (Import ANT : AdjacentNameType NT).

Module A := Adjacency NT NOT NSet ANT.
Import A.

Module AG := Aggregation NT NOT NSet NOTC NMap CFG ANT.
Import AG.AX.

Module TR := Tree NT NOT NSet NOTC NMap RNT ANT.
Import TR.AX.

Import GroupScope.

Module NSetFacts := Facts NSet.
Module NSetProps := Properties NSet.
Module NSetOrdProps := OrdProperties NSet.

Inductive Msg : Type := 
| Aggregate : m -> Msg
| Fail : Msg
| Level : option lv -> Msg.

Definition Msg_eq_dec : forall x y : Msg, {x = y} + {x <> y}.
decide equality; first exact: m_eq_dec.
case: o; case: o0.
- move => n m.
  case (lv_eq_dec n m) => H_dec; first by rewrite H_dec; left.
  right.
  move => H_eq.
  injection H_eq => H_eq'.
  by rewrite H_eq' in H_dec.
- by right.
- by right.
- by left.
Defined.

Inductive Input : Type :=
| Local : m -> Input
| SendAggregate : Input
| AggregateRequest : Input
| LevelRequest : Input
| Broadcast : Input.

Definition Input_eq_dec : forall x y : Input, {x = y} + {x <> y}.
decide equality.
exact: m_eq_dec.
Defined.

Inductive Output : Type :=
| AggregateResponse : m -> Output
| LevelResponse : option lv -> Output.

Definition Output_eq_dec : forall x y : Output, {x = y} + {x <> y}.
decide equality; first exact: m_eq_dec.
case: o; case: o0.
- move => n m.
  case (lv_eq_dec n m) => H_dec; first by rewrite H_dec; left.
  right.
  move => H_eq.
  injection H_eq => H_eq'.
  by rewrite H_eq' in H_dec.
- by right.
- by right.
- by left.
Defined.

Record Data :=  mkData { 
  local : m ; 
  aggregate : m ; 
  adjacent : NS ; 
  sent : NM ; 
  received : NM ;
  broadcast : bool ; 
  levels : NL
}.

Definition InitData (n : name) := 
if root_dec n then
  {| local := 1 ;
     aggregate := 1 ;
     adjacent := adjacency n nodes ;
     sent := init_map (adjacency n nodes) ;
     received := init_map (adjacency n nodes) ;
     broadcast := true ;
     levels := NMap.empty lv |}
else
  {| local := 1 ;
     aggregate := 1 ;
     adjacent := adjacency n nodes ;
     sent := init_map (adjacency n nodes) ;
     received := init_map (adjacency n nodes) ;
     broadcast := false ;
     levels := NMap.empty lv |}.

Definition Handler (S : Type) := GenHandler (name * Msg) S Output unit.

Definition RootNetHandler (src : name) (msg : Msg) : Handler Data :=
st <- get ;;
match msg with 
| Aggregate m_msg => 
  match NMap.find src st.(received) with
  | None => nop
  | Some m_src => 
    put {| local := st.(local) ;
           aggregate := st.(aggregate) * m_msg ;
           adjacent := st.(adjacent) ;
           sent := st.(sent) ;
           received := NMap.add src (m_src * m_msg) st.(received) ;
           broadcast := st.(broadcast) ;
           levels := st.(levels) |}
  end
| Level _ => nop 
| Fail => 
  match NMap.find src st.(sent), NMap.find src st.(received) with
  | Some m_snt, Some m_rcd =>    
    put {| local := st.(local) ;
           aggregate := st.(aggregate) * m_snt * (m_rcd)^-1 ;
           adjacent := NSet.remove src st.(adjacent) ;
           sent := NMap.remove src st.(sent) ;
           received := NMap.remove src st.(received) ;
           broadcast := st.(broadcast) ;
           levels := st.(levels) |}
  | _, _ =>
    put {| local := st.(local) ;
           aggregate := st.(aggregate) ;
           adjacent := NSet.remove src st.(adjacent) ;
           sent := st.(sent) ;
           received := st.(received) ;
           broadcast := st.(broadcast) ;
           levels := st.(levels) |}
  end
end.

Definition NonRootNetHandler (me src: name) (msg : Msg) : Handler Data :=
st <- get ;;
match msg with
| Aggregate m_msg => 
  match NMap.find src st.(received) with
  | None => nop
  | Some m_src => 
    put {| local := st.(local) ;
           aggregate := st.(aggregate) * m_msg ;
           adjacent := st.(adjacent) ;
           sent := st.(sent) ;
           received := NMap.add src (m_src * m_msg) st.(received) ;
           broadcast := st.(broadcast) ;
           levels := st.(levels) |}
  end
| Level None =>
  if olv_eq_dec (level st.(adjacent) st.(levels)) (level st.(adjacent) (NMap.remove src st.(levels))) then
    put {| local := st.(local) ;
           aggregate := st.(aggregate) ;
           adjacent := st.(adjacent) ;
           sent := st.(sent) ;
           received := st.(received) ;
           broadcast := st.(broadcast) ;
           levels := NMap.remove src st.(levels) |}
  else 
    put {| local := st.(local) ;
           aggregate := st.(aggregate) ;
           adjacent := st.(adjacent) ;
           sent := st.(sent) ;
           received := st.(received) ;
           broadcast := true ;
           levels := NMap.remove src st.(levels) |}
| Level (Some lv') =>
  if olv_eq_dec (level st.(adjacent) st.(levels)) (level st.(adjacent) (NMap.add src lv' st.(levels))) then
    put {| local := st.(local) ;
           aggregate := st.(aggregate) ;
           adjacent := st.(adjacent) ;
           sent := st.(sent) ;
           received := st.(received) ;
           broadcast := st.(broadcast) ;
           levels := NMap.add src lv' st.(levels) |}
  else
    put {| local := st.(local) ;
           aggregate := st.(aggregate) ;
           adjacent := st.(adjacent) ;
           sent := st.(sent) ;
           received := st.(received) ;
           broadcast := true ;
           levels := NMap.add src lv' st.(levels) |}
| Fail => 
  match NMap.find src st.(sent), NMap.find src st.(received) with
  | Some m_snt, Some m_rcd =>    
    if olv_eq_dec (level st.(adjacent) st.(levels)) (level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels))) then
      put {| local := st.(local) ;
             aggregate := st.(aggregate) * m_snt * (m_rcd)^-1 ;
             adjacent := NSet.remove src st.(adjacent) ;
             sent := NMap.remove src st.(sent) ;
             received := NMap.remove src st.(received) ;
             broadcast := st.(broadcast) ;
             levels := NMap.remove src st.(levels) |}
    else
      put {| local := st.(local) ;
             aggregate := st.(aggregate) * m_snt * (m_rcd)^-1 ;
             adjacent := NSet.remove src st.(adjacent) ;
             sent := NMap.remove src st.(sent) ;
             received := NMap.remove src st.(received) ;
             broadcast := true ;
             levels := NMap.remove src st.(levels) |}
  | _, _ => 
    if olv_eq_dec (level st.(adjacent) st.(levels)) (level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels))) then
      put {| local := st.(local) ;
             aggregate := st.(aggregate) ;
             adjacent := NSet.remove src st.(adjacent) ;
             sent := st.(sent) ;
             received := st.(received) ;
             broadcast := st.(broadcast) ;
             levels := NMap.remove src st.(levels) |}
    else
      put {| local := st.(local) ;
             aggregate := st.(aggregate) ;
             adjacent := NSet.remove src st.(adjacent) ;
             sent := st.(sent) ;
             received := st.(received) ;
             broadcast := true ;
             levels := NMap.remove src st.(levels) |}
  end
end.

Definition NetHandler (me src : name) (msg : Msg) : Handler Data :=
if root_dec me then RootNetHandler src msg 
else NonRootNetHandler me src msg.

Definition level_fold (lvo : option lv) (n : name) (partial : list (name * Msg)) : list (name * Msg) :=
(n, Level lvo) :: partial.

Definition level_adjacent (lvo : option lv) (fs : NS) : list (name * Msg) :=
NSet.fold (level_fold lvo) fs [].

Definition send_level_fold (lvo : option lv) (n : name) (res : Handler Data) : Handler Data :=
send (n, Level lvo) ;; res.

Definition send_level_adjacent (lvo : option lv) (fs : NS) : Handler Data :=
NSet.fold (send_level_fold lvo) fs nop.

Definition RootIOHandler (i : Input) : Handler Data :=
st <- get ;;
match i with
| Local m_msg => 
  put {| local := m_msg;
         aggregate := st.(aggregate) * m_msg * st.(local)^-1;
         adjacent := st.(adjacent);
         sent := st.(sent);
         received := st.(received);
         broadcast := st.(broadcast);
         levels := st.(levels) |}
| SendAggregate => nop
| AggregateRequest => 
  write_output (AggregateResponse st.(aggregate))
| Broadcast => 
  when st.(broadcast)
  (send_level_adjacent (Some 0) st.(adjacent) ;;
   put {| local := st.(local);
          aggregate := st.(aggregate);
          adjacent := st.(adjacent);
          sent := st.(sent);
          received := st.(received);
          broadcast := false;
          levels := st.(levels) |})
| LevelRequest => 
  write_output (LevelResponse (Some 0))
end.

Definition NonRootIOHandler (i : Input) : Handler Data :=
st <- get ;;
match i with
| Local m_msg => 
  put {| local := m_msg; 
         aggregate := st.(aggregate) * m_msg * st.(local)^-1;
         adjacent := st.(adjacent); 
         sent := st.(sent);
         received := st.(received);
         broadcast := st.(broadcast);
         levels := st.(levels) |}
| SendAggregate => 
  when (sumbool_not _ _ (m_eq_dec st.(aggregate) 1))
  (match parent st.(adjacent) st.(levels) with
  | None => nop
  | Some dst => 
    match NMap.find dst st.(sent) with
    | None => nop
    | Some m_dst =>   
      send (dst, (Aggregate st.(aggregate))) ;;
      put {| local := st.(local);
             aggregate := 1;
             adjacent := st.(adjacent);
             sent := NMap.add dst (m_dst * st.(aggregate)) st.(sent);
             received := st.(received);
             broadcast := st.(broadcast);
             levels := st.(levels) |}
    end
  end)
| AggregateRequest => 
  write_output (AggregateResponse st.(aggregate))
| Broadcast =>
  when st.(broadcast)
  (send_level_adjacent (level st.(adjacent) st.(levels)) st.(adjacent) ;; 
  put {| local := st.(local);
         aggregate := st.(aggregate);
         adjacent := st.(adjacent);
         sent := st.(sent);
         received := st.(received);
         broadcast := false;
         levels := st.(levels) |})
| LevelRequest =>   
  write_output (LevelResponse (level st.(adjacent) st.(levels)))
end.

Definition IOHandler (me : name) (i : Input) : Handler Data :=
if root_dec me then RootIOHandler i 
else NonRootIOHandler i.

Instance TreeAggregation_BaseParams : BaseParams :=
  {
    data := Data;
    input := Input;
    output := Output
  }.

Instance TreeAggregation_MultiParams : MultiParams TreeAggregation_BaseParams :=
  {
    name := name ;
    msg  := Msg ;
    msg_eq_dec := Msg_eq_dec ;
    name_eq_dec := name_eq_dec ;
    nodes := nodes ;
    all_names_nodes := all_names_nodes ;
    no_dup_nodes := no_dup_nodes ;
    init_handlers := InitData ;
    net_handlers := fun dst src msg s =>
                      runGenHandler_ignore s (NetHandler dst src msg) ;
    input_handlers := fun nm msg s =>
                        runGenHandler_ignore s (IOHandler nm msg)
  }.

Instance TreeAggregation_NameOverlayParams : NameOverlayParams TreeAggregation_MultiParams :=
  {
    adjacent_to := adjacent_to ;
    adjacent_to_dec := adjacent_to_dec ;
    adjacent_to_symmetric := adjacent_to_symmetric ;
    adjacent_to_irreflexive := adjacent_to_irreflexive
  }.

Instance TreeAggregation_FailMsgParams : FailMsgParams TreeAggregation_MultiParams :=
  {
    msg_fail := Fail
  }.

Lemma net_handlers_NetHandler :
  forall dst src m st os st' ms,
    net_handlers dst src m st = (os, st', ms) ->
    NetHandler dst src m st = (tt, os, st', ms).
Proof.
intros.
simpl in *.
monad_unfold.
repeat break_let.
find_inversion.
destruct u. auto.
Qed.

Lemma NetHandler_cases : 
  forall dst src msg st out st' ms,
    NetHandler dst src msg st = (tt, out, st', ms) ->
    (exists m_msg m_src, msg = Aggregate m_msg /\ 
     NMap.find src st.(received) = Some m_src /\
     st'.(local) = st.(local) /\
     st'.(aggregate) = st.(aggregate) * m_msg /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(sent) = st.(sent) /\     
     st'.(received) = NMap.add src (m_src * m_msg) st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = st.(levels) /\
     out = [] /\ ms = []) \/
    (exists m_msg, msg = Aggregate m_msg /\ 
     NMap.find src st.(received) = None /\ 
     st' = st /\ 
     out = [] /\ ms = []) \/
    (root dst /\ msg = Fail /\ 
     exists m_snt m_rcd, NMap.find src st.(sent) = Some m_snt /\ NMap.find src st.(received) = Some m_rcd /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) * m_snt * (m_rcd)^-1 /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(sent) = NMap.remove src st.(sent) /\
     st'.(received) = NMap.remove src st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Fail /\ 
     exists m_snt m_rcd, NMap.find src st.(sent) = Some m_snt /\ NMap.find src st.(received) = Some m_rcd /\
     level st.(adjacent) st.(levels) = level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) * m_snt * (m_rcd)^-1 /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(sent) = NMap.remove src st.(sent) /\
     st'.(received) = NMap.remove src st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Fail /\ 
     exists m_snt m_rcd, NMap.find src st.(sent) = Some m_snt /\ NMap.find src st.(received) = Some m_rcd /\
     level st.(adjacent) st.(levels) <> level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) * m_snt * (m_rcd)^-1 /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(sent) = NMap.remove src st.(sent) /\
     st'.(received) = NMap.remove src st.(received) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (root dst /\ msg = Fail /\ (NMap.find src st.(sent) = None \/ NMap.find src st.(received) = None) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Fail /\ (NMap.find src st.(sent) = None \/ NMap.find src st.(received) = None) /\
     level st.(adjacent) st.(levels) = level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Fail /\ (NMap.find src st.(sent) = None \/ NMap.find src st.(received) = None) /\
     level st.(adjacent) st.(levels) <> level (NSet.remove src st.(adjacent)) (NMap.remove src st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = NSet.remove src st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (root dst /\ exists lvo, msg = Level lvo /\ 
     st' = st /\
     out = [] /\ ms = []) \/
    (~ root dst /\ exists lv_msg, msg = Level (Some lv_msg) /\
     level st.(adjacent) st.(levels) = level st.(adjacent) (NMap.add src lv_msg st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.add src lv_msg st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ exists lv_msg, msg = Level (Some lv_msg) /\
     level st.(adjacent) st.(levels) <> level st.(adjacent) (NMap.add src lv_msg st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.add src lv_msg st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Level None /\
     level st.(adjacent) st.(levels) = level st.(adjacent) (NMap.remove src st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = st.(broadcast) /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []) \/
    (~ root dst /\ msg = Level None /\
     level st.(adjacent) st.(levels) <> level st.(adjacent) (NMap.remove src st.(levels)) /\
     st'.(local) = st.(local) /\ 
     st'.(aggregate) = st.(aggregate) /\
     st'.(adjacent) = st.(adjacent) /\
     st'.(sent) = st.(sent) /\
     st'.(received) = st.(received) /\
     st'.(broadcast) = true /\
     st'.(levels) = NMap.remove src st.(levels) /\
     out = [] /\ ms = []).
Proof.
move => dst src msg st out st' ms.
rewrite /NetHandler /RootNetHandler /NonRootNetHandler.
case: msg => [m_msg||olv_msg]; monad_unfold.
- case root_dec => /= H_dec; case H_find: (NMap.find _ _) => [m_src|] /= H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
  * by left; exists m_msg; exists m_src.
  * by right; left; exists m_msg.
  * by left; exists m_msg; exists m_src.
  * by right; left; exists m_msg.
- case root_dec => /= H_dec; case H_find: (NMap.find _ _) => [m_snt|]; case H_find': (NMap.find _ _) => [m_rcd|] /=.
  * move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
    right; right; left.
    split => //.
    split => //.
    by exists m_snt; exists m_rcd.
  * move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=. 
    right; right; right; right; right; left.
    split => //.
    split => //.
    by split => //; first by right.
  * move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=. 
    right; right; right; right; right; left.
    split => //.
    split => //.
    by split => //; first by left.
  * move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=. 
    right; right; right; right; right; left.
    split => //.
    split => //.
    by split => //; first by left.
  * case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
      right; right; right; left.
      split => //.
      split => //.
      by exists m_snt; exists m_rcd.
    right; right; right; right; left.
    split => //.
    split => //.
    by exists m_snt; exists m_rcd.
  * case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
      right; right; right; right; right; right; left.
      split => //.
      split => //.
      by split; first by right.
    right; right; right; right; right; right; right; left.
    split => //.
    split => //.
    by split; first by right.
  * case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
      right; right; right; right; right; right; left.
      split => //.
      split => //.
      by split; first by left.
    right; right; right; right; right; right; right; left.
    split => //.
    split => //.
    by split; first by left.
  * case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
      right; right; right; right; right; right; left.
      split => //.
      split => //.
      by split; first by left.
    right; right; right; right; right; right; right; left.
    split => //.
    split => //.
    by split; first by left.
- case root_dec => /= H_dec.
    move => H_eq.
    injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
    right; right; right; right; right; right; right; right; left.
    split => //.
    by exists olv_msg.
  case H_olv_dec: olv_msg => [lv_msg|]; case olv_eq_dec => /= H_dec' H_eq; injection H_eq => H_ms H_st H_out; rewrite -H_st /=.
  * right; right; right; right; right; right; right; right; right; left.
    split => //.
    by exists lv_msg.
  * right; right; right; right; right; right; right; right; right; right; left.
    split => //.
    by exists lv_msg.
  * by right; right; right; right; right; right; right; right; right; right; right; left.
  * by right; right; right; right; right; right; right; right; right; right; right; right.
Qed.

Lemma input_handlers_IOHandler :
  forall h i d os d' ms,
    input_handlers h i d = (os, d', ms) ->
    IOHandler h i d = (tt, os, d', ms).
Proof.
intros.
simpl in *.
monad_unfold.
repeat break_let.
find_inversion.
destruct u. auto.
Qed.

Lemma fold_left_level_fold_eq :
forall ns nml olv,
fold_left (fun l n => level_fold olv n l) ns nml = fold_left (fun l n => level_fold olv n l) ns [] ++ nml.
Proof.
elim => //=.
move => n ns IH nml olv.
rewrite /level_fold /=.
rewrite IH.
have IH' := IH ([(n, Level olv)]).
rewrite IH'.
set bla := fold_left _ _ _.
rewrite -app_assoc.
by rewrite app_assoc.
Qed.

Lemma send_level_fold_app :
  forall ns st olv nm,
snd (fold_left 
       (fun (a : Handler Data) (e : NSet.elt) => send_level_fold olv e a) ns
       (fun s : Data => (tt, [], s, nm)) st) = 
snd (fold_left 
       (fun (a : Handler Data) (e : NSet.elt) => send_level_fold olv e a) ns
       (fun s : Data => (tt, [], s, [])) st) ++ nm.
Proof.
elim => //=.
move => n ns IH st olv nm.
rewrite {1}/send_level_fold /=.
monad_unfold.
rewrite /=.
rewrite IH.
rewrite app_assoc.
by rewrite -IH.
Qed.

Lemma send_level_adjacent_fst_eq : 
forall fs olv st,
  snd (send_level_adjacent olv fs st) = level_adjacent olv fs.
Proof.
move => fs olv st.
rewrite /send_level_adjacent /level_adjacent.
rewrite 2!NSet.fold_spec.
move: olv st.
elim: NSet.elements => [|n ns IH] //=.
move => olv st.
rewrite {2}/level_fold {2}/send_level_fold.
rewrite fold_left_level_fold_eq.
have IH' := IH olv st.
rewrite -IH'.
monad_unfold.
by rewrite -send_level_fold_app.
Qed.

Lemma fst_fst_fst_tt_send_level_fold : 
forall ns nm olv st,
fst
  (fst
     (fst
        (fold_left
           (fun (a : Handler Data) (e : NSet.elt) =>
              send_level_fold olv e a) ns
           (fun s : Data => (tt, [], s, nm)) st))) = tt.
Proof.
elim => //=.
move => n ns IH nm olv st.
by rewrite IH.
Qed.

Lemma send_level_adjacent_fst_fst_eq : 
forall fs olv st,
  fst (fst (fst (send_level_adjacent olv fs st))) = tt.
Proof.
move => fs olv st.
rewrite /send_level_adjacent.
rewrite NSet.fold_spec.
by rewrite fst_fst_fst_tt_send_level_fold.
Qed.

Lemma snd_fst_fst_out_send_level_fold : 
forall ns nm olv st,
snd
  (fst
     (fst
        (fold_left
           (fun (a : Handler Data) (e : NSet.elt) =>
              send_level_fold olv e a) ns
           (fun s : Data => (tt, [], s, nm)) st))) = [].
Proof.
elim => //=.
move => n ns IH nm olv st.
by rewrite IH.
Qed.

Lemma snd_fst_st_send_level_fold : 
forall ns nm olv st,
snd (fst
        (fold_left
           (fun (a : Handler Data) (e : NSet.elt) =>
              send_level_fold olv e a) ns
           (fun s : Data => (tt, [], s, nm)) st)) = st.
Proof.
elim => //=.
move => n ns IH nm olv st.
by rewrite IH.
Qed.

Lemma send_level_adjacent_snd_fst_fst : 
forall fs olv st,
  snd (fst (fst (send_level_adjacent olv fs st))) = [].
Proof.
move => fs olv st.
rewrite /send_level_adjacent.
rewrite NSet.fold_spec.
by rewrite snd_fst_fst_out_send_level_fold.
Qed.

Lemma send_level_adjacent_snd_fst : 
forall fs olv st,
  snd (fst (send_level_adjacent olv fs st)) = st.
Proof.
move => fs olv st.
rewrite /send_level_adjacent.
rewrite NSet.fold_spec.
by rewrite snd_fst_st_send_level_fold.
Qed.

Lemma send_level_adjacent_eq : 
  forall fs olv st,
  send_level_adjacent olv fs st = (tt, [], st, level_adjacent olv fs).
Proof.
move => fs olv st.
case H_eq: send_level_adjacent => [[[u o] s b]].
have H_eq'_1 := send_level_adjacent_fst_fst_eq fs olv st.
rewrite H_eq /= in H_eq'_1.
have H_eq'_2 := send_level_adjacent_fst_eq fs olv st.
rewrite H_eq /= in H_eq'_2.
have H_eq'_3 := send_level_adjacent_snd_fst_fst fs olv st.
rewrite H_eq /= in H_eq'_3.
have H_eq'_4 := send_level_adjacent_snd_fst fs olv st.
rewrite H_eq /= in H_eq'_4.
by rewrite H_eq'_1 H_eq'_2 H_eq'_3 H_eq'_4.
Qed.

Lemma IOHandler_cases :
  forall h i st u out st' ms,
      IOHandler h i st = (u, out, st', ms) ->
      (exists m_msg, i = Local m_msg /\ 
         st'.(local) = m_msg /\ 
         st'.(aggregate) = st.(aggregate) * m_msg * st.(local)^-1 /\ 
         st'.(adjacent) = st.(adjacent) /\
         st'.(sent) = st.(sent) /\
         st'.(received) = st.(received) /\
         st'.(broadcast) = st.(broadcast) /\
         st'.(levels) = st.(levels) /\
         out = [] /\ ms = []) \/
      (root h /\ i = SendAggregate /\ 
         st' = st /\
         out = [] /\ ms = []) \/
      (~ root h /\ i = SendAggregate /\ 
       st.(aggregate) <> 1 /\ 
       exists dst m_dst, parent st.(adjacent) st.(levels) = Some dst /\ NMap.find dst st.(sent) = Some m_dst /\
       st'.(local) = st.(local) /\
       st'.(aggregate) = 1 /\ 
       st'.(adjacent) = st.(adjacent) /\
       st'.(sent) = NMap.add dst (m_dst * st.(aggregate)) st.(sent) /\
       st'.(received) = st.(received) /\
       st'.(broadcast) = st.(broadcast) /\
       st'.(levels) = st.(levels) /\
       out = [] /\ ms = [(dst, Aggregate st.(aggregate))]) \/
      (~ root h /\ i = SendAggregate /\
       st.(aggregate) = 1 /\
       st' = st /\
       out = [] /\ ms = []) \/
      (~ root h /\ i = SendAggregate /\
       st.(aggregate) <> 1 /\
       parent st.(adjacent) st.(levels) = None /\ 
       st' = st /\
       out = [] /\ ms = []) \/
      (~ root h /\ i = SendAggregate /\
       st.(aggregate) <> 1 /\
       exists dst, parent st.(adjacent) st.(levels) = Some dst /\ NMap.find dst st.(sent) = None /\ 
       st' = st /\
       out = [] /\ ms = []) \/
      (i = AggregateRequest /\ 
       st' = st /\ 
       out = [AggregateResponse (aggregate st)] /\ ms = []) \/
      (root h /\ i = Broadcast /\ st.(broadcast) = true /\
       st'.(local) = st.(local) /\
       st'.(aggregate) = st.(aggregate) /\ 
       st'.(adjacent) = st.(adjacent) /\
       st'.(sent) = st.(sent) /\
       st'.(received) = st.(received) /\
       st'.(broadcast) = false /\
       st'.(levels) = st.(levels) /\
       out = [] /\ ms = level_adjacent (Some 0) st.(adjacent)) \/
      (~ root h /\ i = Broadcast /\ st.(broadcast) = true /\
       st'.(local) = st.(local) /\
       st'.(aggregate) = st.(aggregate) /\ 
       st'.(adjacent) = st.(adjacent) /\
       st'.(sent) = st.(sent) /\
       st'.(received) = st.(received) /\
       st'.(broadcast) = false /\
       st'.(levels) = st.(levels) /\
       out = [] /\ ms = level_adjacent (level st.(adjacent) st.(levels)) st.(adjacent)) \/
      (i = Broadcast /\ st.(broadcast) = false /\
       st' = st /\
       out = [] /\ ms = []) \/
      (root h /\ i = LevelRequest /\
       st' = st /\
       out = [LevelResponse (Some 0)] /\ ms = []) \/
      (~ root h /\ i = LevelRequest /\
       st' = st /\
       out = [LevelResponse (level st.(adjacent) st.(levels))] /\ ms = []).      
Proof.
move => h i st u out st' ms.
rewrite /IOHandler /RootIOHandler /NonRootIOHandler.
case: i => [m_msg||||]; monad_unfold.
- by case root_dec => /= H_dec H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=; left; exists m_msg.
- case root_dec => /= H_dec. 
    by move => H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=; right; left.
  case sumbool_not => /= H_not; last first. 
    by move => H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=; right; right; right; left.
  case H_p: parent => [dst|]; last first. 
    by move => H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=; right; right; right; right; left.
  case H_find: NMap.find => [m_dst|] H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=.
    right; right; left.
    split => //.
    split => //.
    split => //.
    by exists dst; exists m_dst.
  right; right; right; right; right; left.
  split => //.
  split => //.
  split => //.
  by exists dst.
- by case root_dec => /= H_dec H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=; right; right; right; right; right; right; left.
- case root_dec => /= H_dec H_eq; injection H_eq => H_ms H_st H_out H_tt; rewrite -H_st /=.
    by right; right; right; right; right; right; right; right; right; right; left.
  by right; right; right; right; right; right; right; right; right; right; right.
- case root_dec => /= H_dec; case H_b: broadcast => /=.
  * right; right; right; right; right; right; right; left.
    repeat break_let.
    injection Heqp => H_ms H_st H_out H_tt.
    subst.
    injection Heqp2 => H_ms H_st H_out H_tt.
    subst.
    injection H => H_ms H_st H_out H_tt.
    subst.
    rewrite /=.
    have H_eq := send_level_adjacent_eq st.(adjacent) (Some 0) st.
    rewrite Heqp5 in H_eq.
    injection H_eq => H_eq_ms H_eq_st H_eq_o H_eq_tt.
    rewrite H_eq_ms H_eq_o.
    by rewrite app_nil_l -2!app_nil_end.
  * right; right; right; right; right; right; right; right; right; left.
    injection H => H_ms H_st H_o H_tt.
    by rewrite H_st H_o H_ms.
  * right; right; right; right; right; right; right; right; left.
    repeat break_let.
    injection Heqp => H_ms H_st H_out H_tt.
    subst.
    injection Heqp2 => H_ms H_st H_out H_tt.
    subst.
    injection H => H_ms H_st H_out H_tt.
    subst.
    rewrite /=.
    have H_eq := send_level_adjacent_eq st.(adjacent) (level st.(adjacent) st.(levels)) st.
    rewrite Heqp5 in H_eq.
    injection H_eq => H_eq_ms H_eq_st H_eq_o H_eq_tt.
    rewrite H_eq_ms H_eq_o.
    by rewrite app_nil_l -2!app_nil_end.
  * right; right; right; right; right; right; right; right; right; left.
    injection H => H_ms H_st H_o H_tt.
    by rewrite H_st H_o H_ms.
Qed.

Ltac net_handler_cases := 
  find_apply_lem_hyp NetHandler_cases; 
  intuition idtac; try break_exists; 
  intuition idtac; subst; 
  repeat find_rewrite.

Ltac io_handler_cases := 
  find_apply_lem_hyp IOHandler_cases; 
  intuition idtac; try break_exists; 
  intuition idtac; subst; 
  repeat find_rewrite.

Instance TreeAggregation_Aggregation_name_params_tot_map : MultiParamsNameTotalMap TreeAggregation_MultiParams AG.Aggregation_MultiParams :=
  {
    tot_map_name := id ;
    tot_map_name_inv := id ;
    tot_map_name_inv_inverse := fun _ => Logic.eq_refl ;
    tot_map_name_inverse_inv := fun _ => Logic.eq_refl
  }.

Instance TreeAggregation_Aggregation_params_pt_ext_map : MultiParamsPartialExtendedMap TreeAggregation_Aggregation_name_params_tot_map :=
  {
    pt_ext_map_data := fun d _ => 
      AG.mkData d.(local) d.(aggregate) d.(adjacent) d.(sent) d.(received) ;
    pt_ext_map_input := fun i n d =>
      match i with 
      | Local m => Some (AG.Local m)
      | SendAggregate => 
        if root_dec n then None else
          match parent d.(adjacent) d.(levels) with
          | Some p => Some (AG.SendAggregate p)
          | None => None
          end
      | AggregateRequest => (Some AG.AggregateRequest)
      | _ => None
      end ;
    pt_ext_map_output := fun o => 
      match o with 
      | AggregateResponse m => Some (AG.AggregateResponse m) 
      | _ => None 
      end ;
    pt_ext_map_msg := fun m => 
      match m with 
      | Aggregate m' => Some (AG.Aggregate m')
      | Fail => Some AG.Fail      
      | Level _ => None 
      end   
  }.

Lemma pt_ext_init_handlers_eq : forall n,
  pt_ext_map_data (init_handlers n) n = init_handlers (tot_map_name n).
Proof.
move => n.
rewrite /= /InitData /=.
by case root_dec.
Qed.

Lemma pt_ext_net_handlers_some : forall me src m st m',
  pt_ext_map_msg m = Some m' ->
  pt_ext_mapped_net_handlers me src m st = net_handlers (tot_map_name me) (tot_map_name src) m' (pt_ext_map_data st me).
Proof.
move => me src.
case => //.
  move => m' st mg.
  rewrite /pt_ext_map_msg /=.
  rewrite /pt_ext_mapped_net_handlers /=.
  repeat break_let.
  move => H_eq.
  inversion H_eq.
  rewrite /id /=.
  apply net_handlers_NetHandler in Heqp.
  net_handler_cases => //.
    injection H1 => H_eqx.
    rewrite H_eqx.
    monad_unfold.
    repeat break_let.
    rewrite /=.
    move: Heqp.
    rewrite /AG.NetHandler /=.
    monad_unfold.
    break_let.
    move: Heqp2.
    case H_find: NMap.find => /= [m0|]; last by rewrite H in H_find.
    rewrite H in H_find.
    injection H_find => H_eq_m.
    rewrite H_eq_m.
    repeat break_let.
    move => Heqp Heqp'.      
    rewrite Heqp' in Heqp.
    by inversion Heqp.
  rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  case H_find: NMap.find => /= [m0|]; first by rewrite H in H_find.
  repeat break_let.
  move => Heqp Heqp'.
  rewrite Heqp' in Heqp.
  by inversion Heqp.
move => st.
case => //.
rewrite /pt_ext_map_msg /=.
rewrite /pt_ext_mapped_net_handlers /=.
repeat break_let.
move => H_eq.
inversion H_eq.
rewrite /id /=.
apply net_handlers_NetHandler in Heqp.
net_handler_cases => //.
- monad_unfold.
  repeat break_let.
  rewrite /=.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  case H_find: NMap.find => /= [m0|]; last by rewrite H2 in H_find.
  case H_find': NMap.find => /= [m1|]; last by rewrite H1 in H_find'.
  rewrite H2 in H_find.
  injection H_find => H_eq_m.
  rewrite H_eq_m.
  rewrite H1 in H_find'.
  injection H_find' => H_eq'_m.
  rewrite H_eq'_m.
  repeat break_let.
  move => Heqp Heqp'.
  rewrite Heqp' in Heqp.
  by inversion Heqp.
- monad_unfold.
  repeat break_let.
  rewrite /=.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  case H_find: NMap.find => /= [m0|]; last by rewrite H2 in H_find.
  case H_find': NMap.find => /= [m1|]; last by rewrite H1 in H_find'.
  rewrite H2 in H_find.
  injection H_find => H_eq_m.
  rewrite H_eq_m.
  rewrite H1 in H_find'.
  injection H_find' => H_eq'_m.
  rewrite H_eq'_m.
  repeat break_let.
  move => Heqp Heqp'.
  rewrite Heqp' in Heqp.
  by inversion Heqp.
- monad_unfold.
  repeat break_let.
  rewrite /=.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  case H_find: NMap.find => /= [m0|]; last by rewrite H2 in H_find.
  case H_find': NMap.find => /= [m1|]; last by rewrite H1 in H_find'.
  rewrite H2 in H_find.
  injection H_find => H_eq_m.
  rewrite H_eq_m.
  rewrite H1 in H_find'.
  injection H_find' => H_eq'_m.
  rewrite H_eq'_m.
  repeat break_let.
  move => Heqp Heqp'.
  rewrite Heqp' in Heqp.
  by inversion Heqp.
- rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  case H_find: NMap.find => /= [m0|]; first by rewrite H_find in H10.
  repeat break_let.
  move => Heqp Heqp'.      
  rewrite Heqp' in Heqp.
  by inversion Heqp.
- rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  rewrite /=.
  case H_find': (NMap.find _  st.(received)) => /= [m1|]; first by rewrite H10 in H_find'.
  case H_find: NMap.find => /= [m0|].
    repeat break_let.
    move => Heqp Heqp'.      
    rewrite Heqp' in Heqp.
    by inversion Heqp.
  repeat break_let.
  move => Heqp Heqp'.      
  rewrite Heqp' in Heqp.
  by inversion Heqp.
- rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  rewrite /=.
  case H_find': (NMap.find _  st.(sent)) => /= [m1|]; first by rewrite H11 in H_find'.
  repeat break_let.
  move => H_eq' H_eq''.
  inversion H_eq'; subst.
  by inversion H_eq''.
- rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  rewrite /=.
  case H_find': (NMap.find _  st.(received)) => /= [m1|]; first by rewrite H11 in H_find'.
  case H_find: NMap.find => [m0|].
    repeat break_let.
    move => H_eq' H_eq''.
    inversion H_eq'; subst.
    by inversion H_eq''.
  repeat break_let.
  move => H_eq' H_eq''.
  inversion H_eq'; subst.
  by inversion H_eq''.
- rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  rewrite /=.
  case H_find: NMap.find => [m0|]; first by rewrite H11 in H_find.
  repeat break_let.
  move => H_eq' H_eq''.
  inversion H_eq'; subst.
  by inversion H_eq''.
- rewrite /=.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  rewrite /AG.NetHandler /=.
  monad_unfold.
  break_let.
  move: Heqp2.
  rewrite /=.
  case H_find': (NMap.find _  st.(received)) => /= [m1|]; first by rewrite H11 in H_find'.
  case H_find: NMap.find => [m0|].
    repeat break_let.
    move => H_eq' H_eq''.
    inversion H_eq'; subst.
    by inversion H_eq''.
  repeat break_let.
  move => H_eq' H_eq''.
  inversion H_eq'; subst.
  by inversion H_eq''.  
Qed.

Lemma pt_ext_net_handlers_none : forall me src m st out st' ps,
  pt_ext_map_msg m = None ->
  net_handlers me src m st = (out, st', ps) ->
  pt_ext_map_data st' me = pt_ext_map_data st me /\ pt_ext_map_name_msgs ps = [].
Proof.
move => me src.
case => //.
move => m' d out d' ps H_eq H_eq'.
apply net_handlers_NetHandler in H_eq'.
net_handler_cases => //.
* case: d' H0 H2 H3 H4 H5 H6 H7 H8 => /=. 
  move => local0 aggregate0 adjacent0 sent0 received0 broadcast0 levels0.
  move => H0 H2 H3 H4 H5 H6 H7 H8.
  by rewrite H2 H3 H4 H5 H6.
* case: d' H0 H2 H3 H4 H5 H6 H7 H8 => /=. 
  move => local0 aggregate0 adjacent0 sent0 received0 broadcast0 levels0.
  move => H0 H2 H3 H4 H5 H6 H7 H8.
  by rewrite H2 H3 H4 H5 H6.
* case: d' H0 H2 H3 H4 H5 H6 H7 H8 => /=. 
  move => local0 aggregate0 adjacent0 sent0 received0 broadcast0 levels0.
  move => H0 H2 H3 H4 H5 H6 H7 H8.
  by rewrite H2 H3 H4 H5 H6.
* case: d' H0 H2 H3 H4 H5 H6 H7 H8 => /=. 
  move => local0 aggregate0 adjacent0 sent0 received0 broadcast0 levels0.
  move => H0 H2 H3 H4 H5 H6 H7 H8.
  by rewrite H2 H3 H4 H5 H6.
Qed.

Lemma pt_ext_input_handlers_some : forall me inp st inp',
  pt_ext_map_input inp me st = Some inp' ->
  pt_ext_mapped_input_handlers me inp st = input_handlers (tot_map_name me) inp' (pt_ext_map_data st me).
Proof.
move => me.
case => //.
- move => m' st.
  case => //=.
  move => m'' H_eq.
  injection H_eq => H_eq'.
  rewrite H_eq' {H_eq H_eq'}.
  rewrite /pt_ext_mapped_input_handlers.
  repeat break_let.  
  rewrite /id /=.
  apply input_handlers_IOHandler in Heqp.
  io_handler_cases => //.
  monad_unfold.
  repeat break_let.
  move: Heqp.
  injection H0 => H_eq_m.
  rewrite -H_eq_m {H_eq_m H0}.
  rewrite /AG.IOHandler.
  monad_unfold.
  rewrite /=.
  move => Heqp.
  by inversion Heqp.
- move => st.
  case => //=; first by move => m'; case root_dec => H_dec //=; case: parent.
    move => dst.
    case root_dec => H_dec //=.
    case H_p: parent => [dst'|] H_eq //=.
    rewrite /id /=.
    injection H_eq => H_eq'.
    rewrite -H_eq' {H_eq H_eq'}.
    rewrite /pt_ext_mapped_input_handlers.
    repeat break_let.      
    apply input_handlers_IOHandler in Heqp.
    have H_p' := H_p.
    move: H_p'.
    rewrite /parent.
    case par => H_p' H_eq //=.
    move: H_p' H_eq => /= [nlv' H_min].
    inversion H_min.
    inversion H.
    move => H_eq.
    injection H_eq => H_eq'.
    rewrite -H_eq'.
    rewrite -H_eq' in H_p.
    move {H_eq' H_eq dst'}.
    io_handler_cases => //=.
    * rewrite /id /=.
      injection H7 => H_eq.
      rewrite -H_eq in H6.
      rewrite -H_eq.
      monad_unfold.
      repeat break_let.
      move: Heqp.      
      rewrite /AG.IOHandler.
      monad_unfold.
      rewrite /=.
      repeat break_let.
      move: Heqp2.
      case H_mem: NSet.mem => /=; last by move/negP: H_mem => H_mem; case: H_mem; apply NSetFacts.mem_1.
      case sumbool_not => //= H_not.
      repeat break_let.
      move: Heqp2.
      case H_find: NMap.find => [m0|]; last by rewrite H_find in H6.
      rewrite H_find in H6.
      injection H6 => H_eq'.
      rewrite H_eq'.
      move => H_eq_p H_eq'_p H_eq''_p.
      inversion H_eq''_p.
      subst.
      inversion H_eq'_p; subst.
      rewrite -2!app_nil_end.
      by inversion H_eq_p.
    * monad_unfold.
      repeat break_let.
      move: Heqp.      
      rewrite /AG.IOHandler.
      monad_unfold.
      repeat break_let.
      move: Heqp2.
      case H_mem: NSet.mem => /=; last by move/negP: H_mem => H_mem; case: H_mem; apply NSetFacts.mem_1.
      case sumbool_not => //= H_not.
      move => H_eq H_eq'.
      rewrite H_eq' in H_eq.
      by inversion H_eq.
    * injection H7 => H_eq.
      rewrite -H_eq in H6.
      monad_unfold.
      repeat break_let.
      move: Heqp.
      rewrite /AG.IOHandler.
      monad_unfold.
      repeat break_let.
      move: Heqp2.
      case H_mem: NSet.mem => /=; last by move/negP: H_mem => H_mem; case: H_mem; apply NSetFacts.mem_1.
      case sumbool_not => //= H_not.
      repeat break_let.
      move: Heqp2.
      case H_find: NMap.find => [m0|]; first by rewrite H_find in H6.
      rewrite -2!app_nil_end.
      move => H_eq_1 H_eq_2 H_eq3.
      inversion H_eq3; subst.
      inversion H_eq_2; subst.
      by inversion H_eq_1.
    * by case root_dec => //= H_dec; case: parent.
- move => st.
  case => //.
  rewrite /pt_ext_map_input /= => H_eq.
  rewrite /pt_ext_mapped_input_handlers.
  repeat break_let.  
  rewrite /id /=.
  apply input_handlers_IOHandler in Heqp.
  by io_handler_cases.
Qed.

Lemma pt_ext_map_name_msgs_level_adjacent_empty : 
  forall fs lvo,
  pt_ext_map_name_msgs (level_adjacent lvo fs) = [].
Proof.
move => fs lvo.
rewrite /level_adjacent NSet.fold_spec.
elim: NSet.elements => //=.
move => n ns IH.
rewrite {2}/level_fold /=.
rewrite fold_left_level_fold_eq /=.
by rewrite pt_ext_map_name_msgs_app_distr /= -app_nil_end IH.
Qed.

Lemma pt_ext_input_handlers_none : forall me inp st out st' ps,
  pt_ext_map_input inp me st = None ->
  input_handlers me inp st = (out, st', ps) ->
  pt_ext_map_data st' me = pt_ext_map_data st me /\ pt_ext_map_name_msgs ps = [].
Proof.
move => me.
case => //=.
- move => st out st' ps.
  case root_dec => /= H_dec.    
    move => H_eq.
    monad_unfold.
    repeat break_let.
    move => H_eq'.
    by io_handler_cases => //=; inversion H_eq'.
  case H_p: parent => [dst'|] H_eq //=.
  monad_unfold.
  repeat break_let.
  move => H_eq'.
  io_handler_cases; inversion H_eq' => //=.
  by rewrite -H4 H1.
- move => st out st' ps H_eq.
  monad_unfold.
  repeat break_let.
  move => H_eq'.
  by io_handler_cases; inversion H_eq' => //=.
- move => st out st' ps H_eq.
  monad_unfold.
  repeat break_let.
  move => H_eq'.
  io_handler_cases; inversion H_eq' => //=.
  * by rewrite -H2 -H3 -H4 -H5 -H6 H11.
  * by rewrite pt_ext_map_name_msgs_level_adjacent_empty.
  * by rewrite -H2 -H3 -H4 -H5 -H6 H11.
  * by rewrite pt_ext_map_name_msgs_level_adjacent_empty.
Qed.

Lemma fail_msg_fst_snd : pt_ext_map_msg msg_fail = Some (msg_fail).
Proof. by []. Qed.

Lemma adjacent_to_fst_snd : 
  forall n n', adjacent_to n n' <-> adjacent_to (tot_map_name n) (tot_map_name n').
Proof. by []. Qed.

Theorem TreeAggregation_Aggregation_pt_ext_mapped_simulation_star_1 :
forall net failed tr,
    @step_o_f_star _ _ TreeAggregation_NameOverlayParams TreeAggregation_FailMsgParams step_o_f_init (failed, net) tr ->
    exists tr', @step_o_f_star _ _ AG.Aggregation_NameOverlayParams AG.Aggregation_FailMsgParams step_o_f_init (failed, pt_ext_map_onet net) tr'.
Proof.
have H_sim := @step_o_f_pt_ext_mapped_simulation_star_1 _ _ _ _ _ TreeAggregation_Aggregation_params_pt_ext_map pt_ext_init_handlers_eq pt_ext_net_handlers_some pt_ext_net_handlers_none pt_ext_input_handlers_some pt_ext_input_handlers_none TreeAggregation_NameOverlayParams AG.Aggregation_NameOverlayParams adjacent_to_fst_snd _ _ fail_msg_fst_snd.
rewrite /tot_map_name /= /id in H_sim.
move => onet failed tr H_st.
apply H_sim in H_st.
move: H_st => [tr' H_st].
rewrite map_id in H_st.
by exists tr'.
Qed.

Instance TreeAggregation_Tree_base_params_pt_map : BaseParamsPartialMap TreeAggregation_BaseParams TR.Tree_BaseParams :=
  {
    pt_map_data := fun d => TR.mkData d.(adjacent) d.(broadcast) d.(levels) ;
    pt_map_input := fun i =>
                   match i with
                   | LevelRequest => Some TR.LevelRequest
                   | Broadcast => Some TR.Broadcast
                   | _ => None
                   end ;
    pt_map_output := fun o => 
                    match o with
                    | LevelResponse olv => Some (TR.LevelResponse olv)
                    | _ => None
                    end
  }.

Instance TreeAggregation_Tree_name_params_tot_map : MultiParamsNameTotalMap TreeAggregation_MultiParams TR.Tree_MultiParams :=
  {
    tot_map_name := id ;
    tot_map_name_inv := id ;
    tot_map_name_inv_inverse := fun _ => Logic.eq_refl ;
    tot_map_name_inverse_inv := fun _ => Logic.eq_refl
  }.

Instance TreeAggregation_Tree_multi_params_pt_map : MultiParamsPartialMap TreeAggregation_Tree_base_params_pt_map TreeAggregation_Tree_name_params_tot_map :=
  {
    pt_map_msg := fun m => match m with 
                        | Fail => Some TR.Fail 
                        | Level lvo => Some (TR.Level lvo)
                        | _ => None 
                        end ;
  }.

Lemma pt_init_handlers_eq : forall n,
  pt_map_data (init_handlers n) = init_handlers (tot_map_name n).
Proof.
move => n.
rewrite /= /InitData /= /TR.InitData /= /id /=.
by case root_dec => /= H_dec.
Qed.

Lemma pt_net_handlers_some : forall me src m st m',
  pt_map_msg m = Some m' ->
  pt_mapped_net_handlers me src m st = net_handlers (tot_map_name me) (tot_map_name src) m' (pt_map_data st).
Proof.
Proof.
move => me src.
case => // [d|].
  case => H_eq //.
  rewrite /pt_mapped_net_handlers.
  repeat break_let.
  apply net_handlers_NetHandler in Heqp.
  net_handler_cases => //=.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    monad_unfold.
    repeat break_let.
    move: Heqp.
    case root_dec => /= H_dec H_eq_st //.
    rewrite H5 H8 H9.
    by inversion H_eq_st.   
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    monad_unfold.
    repeat break_let.
    move: Heqp.
    case root_dec => /= H_dec H_eq_st //.
    repeat break_let.
    move: Heqp2.
    case olv_eq_dec => /= H_dec' H_st //.
    rewrite H6 H9 H10.
    inversion H_st; subst.
    by inversion H_eq_st.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    repeat break_let.
    move: Heqp0.
    case olv_eq_dec => /= H_dec' //.
    move => Heqp0.
    rewrite H6 H9 H10.
    inversion Heqp0; subst.
    by inversion Heqp.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    by rewrite H4 H7 H8.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    by rewrite H4 H7 H8.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    repeat break_let.
    move: Heqp0.
    case olv_eq_dec => /= H_dec' //.
    move => H_eq'.
    rewrite H5 H8 H9.
    inversion H_eq'; subst.
    by inversion Heqp.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    repeat break_let.
    move: Heqp0.
    case olv_eq_dec => /= H_dec' //.
    move => H_eq'.
    rewrite H5 H8 H9.
    inversion H_eq'; subst.
    by inversion Heqp.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    repeat break_let.
    move: Heqp0.
    case olv_eq_dec => /= H_dec' //.
    move => H_eq'.
    rewrite H5 H8 H9.
    inversion H_eq'; subst.
    by inversion Heqp.
  - rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=.
    case root_dec => /= H_dec //=.
    monad_unfold.
    rewrite /=.
    repeat break_let.
    move: Heqp0.
    case olv_eq_dec => /= H_dec' //.
    move => H_eq'.
    rewrite H5 H8 H9.
    inversion H_eq'; subst.
    by inversion Heqp.
move => olv st.
case => // olv' H_eq.
rewrite /pt_map_msg /= in H_eq.
injection H_eq => H_eq_olv.
rewrite -H_eq_olv {H_eq_olv H_eq olv'}.
rewrite /pt_mapped_net_handlers.
repeat break_let.
apply net_handlers_NetHandler in Heqp.
net_handler_cases => //=; rewrite /id /= /TR.NetHandler /= /TR.RootNetHandler /TR.NonRootNetHandler /=; case root_dec => /= H_dec; monad_unfold => //.
- injection H1 => H_eq_olv.
  repeat break_let.
  move: Heqp0.
  case H_eq_olv': olv => /= [lv'|]; case olv_eq_dec => /= H_dec' //= H_st.
  * rewrite H_eq_olv' in H_eq_olv.
    injection H_eq_olv => H_eq_olv_eq.
    inversion H_st; subst.
    inversion Heqp; subst.
    by rewrite H4 H7 H8.
  * inversion H_st; subst.
    inversion Heqp; subst.
    injection H_eq_olv' => H_eq.
    by rewrite -H_eq in H_dec'.
  * inversion H_st; subst.
    inversion Heqp; subst.
    by rewrite H4 H7 H8.
  * by inversion H_st; subst.
- injection H1 => H_eq_olv.
  repeat break_let.
  move: Heqp0.
  case H_eq_olv': olv => /= [lv'|]; case olv_eq_dec => /= H_dec' //= H_st.
  * rewrite H_eq_olv' in H_eq_olv.
    injection H_eq_olv => H_eq_olv_eq.
    inversion H_st; subst.
    inversion Heqp; subst.
    by rewrite H4 H7 H8.
  * inversion H_st; subst.
    inversion Heqp; subst.
    injection H_eq_olv' => H_eq.
    by rewrite H4 H7 H8 H_eq.
  * inversion H_st; subst.
    inversion Heqp; subst.
    by rewrite H4 H7 H8.
  * by inversion H_st; subst.
- inversion H0.
  repeat break_let.
  move: Heqp0.
  case olv_eq_dec => /= H_dec' //.
  move => H_eq'.
  inversion H_eq'; subst.
  inversion Heqp; subst.
  by rewrite H4 H7 H8.
- inversion H0.
  repeat break_let.
  move: Heqp0.
  case olv_eq_dec => /= H_dec' //.
  move => H_eq'.
  inversion H_eq'; subst.
  inversion Heqp; subst.
  by rewrite H4 H7 H8.
Qed.

Lemma pt_net_handlers_none : forall me src m st out st' ps,    
  pt_map_msg m = None ->
  net_handlers me src m st = (out, st', ps) ->
  pt_map_data st' = pt_map_data st /\ pt_map_name_msgs ps = [] /\ pt_map_outputs out = [].
Proof.
move => me src.
case => //.
move => olv d out d' ps H_eq H_eq'.
apply net_handlers_NetHandler in H_eq'.
net_handler_cases => //.
case: d' H1 H2 H3 H4 H5 H6 H7 => /= local0 aggregate0 adjacent0 sent0 received0 broadcast0 levels0. 
move => H_eq_l H_eq_a H_eq_ad H_eq_s H_eq_r H_eq_b H_eq_lv.
by rewrite H_eq_ad H_eq_b H_eq_lv.
Qed.

Lemma pt_input_handlers_some : forall me inp st inp',
  pt_map_input inp = Some inp' ->
  pt_mapped_input_handlers me inp st = input_handlers (tot_map_name me) inp' (pt_map_data st).
Proof.
move => me.
case => //= st; case => //= H_eq; rewrite /id /= /TR.IOHandler /TR.RootIOHandler /TR.NonRootIOHandler; case root_dec => /= H_dec; monad_unfold => //=.
- rewrite /pt_mapped_input_handlers /=.
  repeat break_let.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //.
  by inversion Heqp.
- rewrite /pt_mapped_input_handlers /=.
  repeat break_let.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //.
  by inversion Heqp.
- repeat break_let.
  move: Heqp0.
  case H_b: broadcast.
    repeat break_let.
    move => H_eq'.
    inversion Heqp; subst => {Heqp}.
    inversion H_eq'; subst => {H_eq'}.
    inversion Heqp0; subst => {Heqp0}.
    rewrite 4!app_nil_r.
    rewrite /pt_mapped_input_handlers /=.
    repeat break_let.
    monad_unfold.
    repeat break_let.
    io_handler_cases => //.
    inversion Heqp; subst => {Heqp}.
    rewrite /=.    
    rewrite H4 H7 H8.
    move: Heqp5.
    set sla := TR.send_level_adjacent _ _ _.
    move => Heqp.
    have H_snd: snd sla = TR.level_adjacent (Some 0) st.(adjacent) by rewrite TR.send_level_adjacent_fst_eq.
    rewrite Heqp /= in H_snd.
    have H_snd_fst_fst: snd (fst (fst sla)) = [] by rewrite TR.send_level_adjacent_snd_fst_fst.
    rewrite Heqp /= in H_snd_fst_fst.
    rewrite H_snd H_snd_fst_fst.
    set ptl := pt_map_name_msgs _.
    set ptl' := TR.level_adjacent _ _.
    suff H_suff: ptl = ptl' by rewrite H_suff.
    rewrite /ptl /ptl' /=.
    rewrite /level_adjacent /TR.level_adjacent 2!NSet.fold_spec.
    elim: NSet.elements => //=.
    move => n ns IH.
    rewrite fold_left_level_fold_eq pt_map_name_msgs_app_distr /= /id /=.
    by rewrite TR.fold_left_level_fold_eq IH.
  move => H_eq'.
  inversion Heqp; subst.
  inversion H_eq'; subst.
  rewrite /pt_mapped_input_handlers /=.
  repeat break_let.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //.
  inversion Heqp0; subst.
  by rewrite H_b.
- repeat break_let.
  move: Heqp0.
  case H_b: broadcast.  
    repeat break_let.
    move => H_eq'.
    inversion Heqp; subst => {Heqp}.
    inversion H_eq'; subst => {H_eq'}.
    inversion Heqp0; subst => {Heqp0}.
    rewrite 4!app_nil_r.
    rewrite /pt_mapped_input_handlers /=.
    repeat break_let.
    monad_unfold.
    repeat break_let.
    io_handler_cases => //.
    inversion Heqp; subst => {Heqp}.
    rewrite /=.    
    rewrite H4 H7 H8.
    move: Heqp5.
    set sla := TR.send_level_adjacent _ _ _.
    move => Heqp.
    have H_snd: snd sla = TR.level_adjacent (level (adjacent st) (levels st)) st.(adjacent) by rewrite TR.send_level_adjacent_fst_eq.
    rewrite Heqp /= in H_snd.
    have H_snd_fst_fst: snd (fst (fst sla)) = [] by rewrite TR.send_level_adjacent_snd_fst_fst.
    rewrite Heqp /= in H_snd_fst_fst.
    rewrite H_snd H_snd_fst_fst.
    set ptl := pt_map_name_msgs _.
    set ptl' := TR.level_adjacent _ _.
    suff H_suff: ptl = ptl' by rewrite H_suff.
    rewrite /ptl /ptl' /=.
    rewrite /level_adjacent /TR.level_adjacent 2!NSet.fold_spec.
    elim: NSet.elements => //=.
    move => n ns IH.
    rewrite fold_left_level_fold_eq pt_map_name_msgs_app_distr /= /id /=.
    by rewrite TR.fold_left_level_fold_eq IH.
  move => H_eq'.
  inversion Heqp; subst.
  inversion H_eq'; subst.
  rewrite /pt_mapped_input_handlers /=.
  repeat break_let.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //.
  inversion Heqp0; subst.
  by rewrite H_b.
Qed.

Lemma pt_input_handlers_none : forall me inp st out st' ps,
  pt_map_input inp = None ->
  input_handlers me inp st = (out, st', ps) ->
  pt_map_data st' = pt_map_data st /\ pt_map_name_msgs ps = [] /\ pt_map_outputs out = [].
Proof.
move => me.
case => //=.
- move => m' st out st' ps H_eq H_eq'.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //.
  * inversion H_eq'; subst.
    by rewrite H2 H5 H6.
  * by inversion H_eq'.
  * by inversion H_eq'.
- move => st out st' ps H_eq H_eq'.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //; inversion H_eq' => //=.
  inversion H_eq'; subst.
  by rewrite H6 H9 H10.
- move => st out st' ps H_eq.
  monad_unfold.
  repeat break_let.
  io_handler_cases => //.
  * by inversion H; subst.
  * by inversion H.
  * by inversion H.
Qed.

Lemma pt_fail_msg_fst_snd : pt_map_msg msg_fail = Some (msg_fail).
Proof. by []. Qed.

Lemma pt_adjacent_to_fst_snd : 
  forall n n', adjacent_to n n' <-> adjacent_to (tot_map_name n) (tot_map_name n').
Proof. by []. Qed.

Theorem TreeAggregation_Tree_pt_mapped_simulation_star_1 :
forall net failed tr,
    @step_o_f_star _ _ TreeAggregation_NameOverlayParams TreeAggregation_FailMsgParams step_o_f_init (failed, net) tr ->
    exists tr', @step_o_f_star _ _ TR.Tree_NameOverlayParams TR.Tree_FailMsgParams step_o_f_init (failed, pt_map_onet net) tr' /\
    pt_trace_remove_empty_out (pt_map_trace tr) = pt_trace_remove_empty_out tr'.
Proof.
have H_sim := @step_o_f_pt_mapped_simulation_star_1 _ _ _ _ _ _ TreeAggregation_Tree_multi_params_pt_map pt_init_handlers_eq pt_net_handlers_some pt_net_handlers_none pt_input_handlers_some pt_input_handlers_none TreeAggregation_NameOverlayParams TR.Tree_NameOverlayParams adjacent_to_fst_snd _ _ pt_fail_msg_fst_snd.
rewrite /tot_map_name /= /id in H_sim.
move => onet failed tr H_st.
apply H_sim in H_st.
move: H_st => [tr' [H_st H_eq]].
rewrite map_id in H_st.
by exists tr'.
Qed.

Instance AggregationData_Data : AggregationData Data :=
  {
    aggr_local := local ;
    aggr_aggregate := aggregate ;
    aggr_adjacent := adjacent ;
    aggr_sent := sent ;
    aggr_received := received
  }.

Instance AggregationMsg_TreeAggregation : AggregationMsg :=
  {
    aggr_msg := msg ;
    aggr_msg_eq_dec := msg_eq_dec ;
    aggr_fail := Fail ;
    aggr_of := fun mg => match mg with | Aggregate m' => m' | _ => 1 end
  }.

Instance AggregationMsgMap_Aggregation_TreeAggregation : AggregationMsgMap AggregationMsg_TreeAggregation AG.AggregationMsg_Aggregation :=
  {
    map_msgs := pt_ext_map_msgs ;    
  }.
Proof.
- elim => //=.
  case => [m'||olv] ms IH /=.
  * by rewrite /aggregate_sum_fold /= IH.
  * by rewrite /aggregate_sum_fold /= IH.
  * by rewrite /aggregate_sum_fold /= IH; gsimpl.
- elim => //=.
  case => [m'||olv] ms IH /=.
  * by split => H_in; case: H_in => H_in //; right; apply IH.
  * by split => H_in; left.
  * split => H_in; last by right; apply IH.
    case: H_in => H_in //.
    by apply IH.
Defined.

Lemma TreeAggregation_conserves_network_mass : 
  forall onet failed tr,
  step_o_f_star step_o_f_init (failed, onet) tr ->
  conserves_network_mass (exclude failed nodes) nodes onet.(onwPackets) onet.(onwState).
Proof.
move => onet failed tr H_st.
have [tr' H_st'] := TreeAggregation_Aggregation_pt_ext_mapped_simulation_star_1 H_st.
have H_inv := AG.Aggregation_conserves_network_mass H_st'.
rewrite /= /id /= /conserves_network_mass in H_inv.
rewrite /conserves_network_mass.
move: H_inv.
set state := fun n : name => _.
set packets := fun src dst : name => _.
rewrite (sum_local_aggr_local_eq _ (onwState onet)) //.
move => H_inv.
rewrite H_inv {H_inv}.
rewrite (sum_aggregate_aggr_aggregate_eq _ (onwState onet)) //.
rewrite sum_aggregate_msg_incoming_active_map_msgs_eq /map_msgs /= -/packets.
rewrite (sum_fail_sent_incoming_active_map_msgs_eq _ state) /map_msgs /= -/packets //.
by rewrite (sum_fail_received_incoming_active_map_msgs_eq _ state) /map_msgs /= -/packets.
Qed.

End TreeAggregation.