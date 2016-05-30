Require Import List.
Import ListNotations.

Require Import Arith.
Require Import ZArith.
Require Import Omega.

Require Import StructTact.StructTactics.
Require Import HandlerMonad.
Require Import Net.
Require Import StructTact.Util.
Require Import TotalMapSimulations.
Require Import PartialMapSimulations.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Require Import FunctionalExtensionality.
Require Import Sumbool.
Require Import Sorting.Permutation.
Require Import OrderedLemmas.

Require Import mathcomp.ssreflect.ssreflect.

Set Implicit Arguments.

Class MultiParamsPartialExtendedMap
 (B0 : BaseParams) (B1 : BaseParams) 
 (P0 : MultiParams B0) (P1 : MultiParams B1) :=
{
  pt_ext_map_data : @data B0 -> @name B0 P0 -> @data B1 ;
  pt_ext_map_input : @input B0 -> @name B0 P0 -> @data B0 -> option (@input B1) 
}.

Section PartialExtendedMapDefs.

Context {base_fst : BaseParams}.
Context {base_snd : BaseParams}.
Context {multi_fst : MultiParams base_fst}.
Context {multi_snd : MultiParams base_snd}.
Context {name_map : MultiParamsNameTotalMap multi_fst multi_snd}.
Context {msg_map : MultiParamsMsgPartialMap multi_fst multi_snd}.
Context {multi_map : MultiParamsPartialExtendedMap multi_fst multi_snd}.

Definition pt_ext_mapped_net_handlers me src m st :=
  let '(_, st', ps) := net_handlers me src m st in
  (pt_ext_map_data st' me, pt_map_name_msgs (name_map := name_map) (msg_map := msg_map) ps).

Definition pt_ext_mapped_input_handlers me inp st :=
  let '(_, st', ps) := input_handlers me inp st in
  (pt_ext_map_data st' me, pt_map_name_msgs (name_map := name_map) (msg_map := msg_map) ps).

End PartialExtendedMapDefs.

Class MultiParamsPartialExtendedMapCongruency
  (B0 : BaseParams) (B1 : BaseParams)
  (P0 : MultiParams B0) (P1 : MultiParams B1)
  (N : MultiParamsNameTotalMap P0 P1)
  (P : MultiParamsMsgPartialMap P0 P1)
  (P : MultiParamsPartialExtendedMap P0 P1) :=
  {
    pt_ext_init_handlers_eq : forall n,
      pt_ext_map_data (init_handlers n) n = init_handlers (tot_map_name n) ;
    pt_ext_net_handlers_some : forall me src m st m' out st' ps,
      pt_map_msg m = Some m' ->
      net_handlers (tot_map_name me) (tot_map_name src) m' (pt_ext_map_data st me) = (out, st', ps) ->
      pt_ext_mapped_net_handlers me src m st = (st', ps) ;
    pt_ext_net_handlers_none : forall me src m st out st' ps,
      pt_map_msg m = None ->
      net_handlers me src m st = (out, st', ps) ->
      pt_ext_map_data st' me = pt_ext_map_data st me /\ pt_map_name_msgs ps = [] ;
    pt_ext_input_handlers_some : forall me inp st inp' out st' ps,
      pt_ext_map_input inp me st = Some inp' ->
      input_handlers (tot_map_name me) inp' (pt_ext_map_data st me) = (out, st', ps) ->
      pt_ext_mapped_input_handlers me inp st = (st', ps) ;
    pt_ext_input_handlers_none : forall me inp st out st' ps,
      pt_ext_map_input inp me st = None ->
      input_handlers me inp st = (out, st', ps) ->
      pt_ext_map_data st' me = pt_ext_map_data st me /\ pt_map_name_msgs ps = []
  }.

Class FailureParamsPartialExtendedMapCongruency
  (B0 : BaseParams) (B1 : BaseParams)
  (P0 : MultiParams B0) (P1 : MultiParams B1)
  (F0 : FailureParams P0) (F1 : FailureParams P1)
  (P : MultiParamsPartialExtendedMap P0 P1) :=
  {
    pt_ext_reboot_eq : forall d me,
      pt_ext_map_data (reboot d) me = reboot (pt_ext_map_data d me)
  }.

Section PartialExtendedMapSimulations.

Context {base_fst : BaseParams}.
Context {base_snd : BaseParams}.
Context {multi_fst : MultiParams base_fst}.
Context {multi_snd : MultiParams base_snd}.
Context {name_map : MultiParamsNameTotalMap multi_fst multi_snd}.
Context {msg_map : MultiParamsMsgPartialMap multi_fst multi_snd}.
Context {multi_map : MultiParamsPartialExtendedMap multi_fst multi_snd}.
Context {name_map_bijective : MultiParamsNameTotalMapBijective name_map}.
Context {multi_map_congr : MultiParamsPartialExtendedMapCongruency name_map msg_map multi_map}.

Lemma pt_ext_init_handlers_fun_eq : 
  init_handlers = fun n : name => pt_ext_map_data (init_handlers (tot_map_name_inv n)) (tot_map_name_inv n).
Proof.
apply functional_extensionality => n.
have H_eq := pt_ext_init_handlers_eq.
rewrite H_eq {H_eq}.
by rewrite tot_map_name_inverse_inv.
Qed.

Definition pt_ext_map_net (net : @network  _ multi_fst) : @network _ multi_snd :=
  {| nwPackets := pt_map_packets net.(nwPackets) ;
     nwState := fun n => pt_ext_map_data (net.(nwState) (tot_map_name_inv n)) (tot_map_name_inv n) |}.

Lemma pt_ext_map_update_eq :
forall f h d,
  (fun n : name => pt_ext_map_data (update f h d (tot_map_name_inv n)) (tot_map_name_inv n)) =
  update (fun n : name => pt_ext_map_data (f (tot_map_name_inv n)) (tot_map_name_inv n)) (tot_map_name h) (pt_ext_map_data d h).
Proof.
move => f h d.
apply functional_extensionality => n.
rewrite /update /=.
case (name_eq_dec _ _) => H_dec; case (name_eq_dec _ _) => H_dec' //.
- rewrite -H_dec in H_dec'.
  by rewrite H_dec.
- case: H_dec'.
  rewrite -H_dec.
  by rewrite tot_map_name_inverse_inv.
- rewrite H_dec' in H_dec.
  by rewrite tot_map_name_inv_inverse in H_dec.
Qed.

Lemma pt_ext_map_update_eq_some :
  forall net d p p',
    pt_map_packet p = Some p' ->
    (fun n : name => pt_ext_map_data (update (nwState net) (pDst p) d (tot_map_name_inv n)) (tot_map_name_inv n)) =
    update (fun n : name => pt_ext_map_data (nwState net (tot_map_name_inv n)) (tot_map_name_inv n)) (pDst p') (pt_ext_map_data d (pDst p)).
Proof.
move => net d p p'.
case: p => src dst m.
case: p' => src' dst' m' /=.
case H_eq: (pt_map_msg _) => [m0|] // H_eq'.
inversion H_eq'; subst.
move {H_eq H_eq'}.
exact: pt_ext_map_update_eq.
Qed.

Theorem step_m_pt_ext_mapped_simulation_1 :
  forall net net' tr,
    @step_m _ multi_fst net net' tr ->
    (exists tr, @step_m _ multi_snd (pt_ext_map_net net) (pt_ext_map_net net') tr) \/ pt_ext_map_net net' = pt_ext_map_net net.
Proof.
move => net net' tr.
case => {net net' tr}.
- move => net net' p ms ms' out d l H_eq H_hnd H_eq'.
  case H_m: (pt_map_packet p) => [p'|].
    left.
    rewrite H_eq' /= /pt_ext_map_net /=.
    have H_eq_dst: tot_map_name (pDst p) = pDst p'.
      case: p H_eq H_hnd H_eq' H_m => /= src dst m H_eq H_hnd H_eq'.
      case (pt_map_msg m) => //= m' H_m.
      by inversion H_m.
    case H_n: (net_handlers (pDst p') (pSrc p') (pBody p') (pt_ext_map_data (nwState net (pDst p)) (pDst p))) => [[out' d'] ps].
    exists [(pDst p', inr out')].
    apply SM_deliver with (xs := pt_map_packets ms) (ys := pt_map_packets ms') (d0 := pt_ext_map_data d (pDst p)) (l0 := pt_map_name_msgs l).
    * rewrite /= H_eq pt_map_packets_app_distr /=.
      case H_p: (pt_map_packet _) => [p0|]; last by rewrite H_p in H_m.
      by rewrite H_p in H_m; injection H_m => H_eq_p; rewrite H_eq_p.
    * rewrite /=.
      rewrite -{2}H_eq_dst tot_map_name_inv_inverse.
      case: p H_eq H_hnd H_eq' H_m H_eq_dst H_n => /= src dst mg H_eq H_hnd H_eq'.
      case H_m: (pt_map_msg mg) => [mg'|] //.
      case: p' H_eq' => src' dst' m0 H_eq' H_eq_p.
      inversion H_eq_p; subst.
      move => H_eq_dst H_eq_n {H_eq_p H_eq_dst}.
      simpl in *.
      have H_q := @pt_ext_net_handlers_some _ _ _ _ _ _ _ multi_map_congr dst src mg (nwState net dst) _ _ _ _ H_m H_eq_n.
      rewrite /pt_ext_mapped_net_handlers in H_q.
      rewrite H_hnd in H_q.
      find_inversion.
      by rewrite tot_map_name_inv_inverse.
    * rewrite /= /pt_ext_map_net /= 2!pt_map_packets_app_distr.
      rewrite (pt_map_packet_map_eq_some _ _ H_m).
      by rewrite (pt_ext_map_update_eq_some _ _ _ H_m).
  right.
  rewrite H_eq' /= {H_eq'}.
  rewrite /pt_ext_map_net /=.
  case: p H_eq H_hnd H_m => /= src dst m H_eq H_hnd.
  case H_m: (pt_map_msg _) => [m'|] // H_eq' {H_eq'}.
  rewrite 2!pt_map_packets_app_distr H_eq pt_map_packets_app_distr /=.
  case H_m': (pt_map_msg _) => [m'|]; first by rewrite H_m' in H_m.
  have [H_d H_l] := pt_ext_net_handlers_none _ _ _ _ H_m H_hnd.
  rewrite (pt_map_name_msgs_empty_eq _ dst H_l) /=.
  set nwS1 := fun _ => _.
  set nwS2 := fun _ => _.
  have H_eq_s: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 /=.
    apply functional_extensionality => n.
    rewrite /update /=.
      case name_eq_dec => H_dec //.
      by rewrite H_dec H_d.
    by rewrite H_eq_s.
- move => h net net' out inp d l H_hnd H_eq.  
  case H_i: (pt_ext_map_input inp h (nwState net h)) => [inp'|].
    left.
    case H_h: (input_handlers (tot_map_name h) inp' (pt_ext_map_data (nwState net h) h)) => [[out' d'] ps].
    exists [(tot_map_name h, inl inp'); (tot_map_name h, inr out')].
    apply (@SM_input _ _ _ _ _ _ _ (pt_ext_map_data d h) (pt_map_name_msgs l)).
      rewrite /=.
      have H_q := @pt_ext_input_handlers_some _ _ _ _ _ _ _ multi_map_congr h inp (nwState net h) _ _ _ _ H_i H_h.
      rewrite /pt_ext_mapped_input_handlers /= in H_q.
      rewrite H_hnd in H_q.
      find_inversion.
      by rewrite tot_map_name_inv_inverse.
    rewrite /= H_eq /= /pt_ext_map_net /= pt_map_packets_app_distr pt_map_packet_map_eq.
    by rewrite -pt_ext_map_update_eq.
  right.
  rewrite H_eq /pt_ext_map_net /=.
  have [H_d H_l] := pt_ext_input_handlers_none _ _ _ H_i H_hnd.
  rewrite pt_map_packets_app_distr.
  rewrite (pt_map_name_msgs_empty_eq _ h H_l) /=.
  set nwS1 := fun _ => _.
  set nwS2 := fun _ => _.
  have H_eq_s: nwS1 = nwS2.
      rewrite /nwS1 /nwS2 /=.
      apply functional_extensionality => n.
      rewrite /update /=.
      case name_eq_dec => H_dec //.
      by rewrite H_dec H_d.
    by rewrite H_eq_s.
Qed.

Corollary step_m_pt_ext_mapped_simulation_star_1 :
  forall net tr,
    @step_m_star _ multi_fst step_m_init net tr ->
    exists tr', @step_m_star _ multi_snd step_m_init (pt_ext_map_net net) tr'.
Proof.
move => net tr H_step.
remember step_m_init as y in *.
move: Heqy.
induction H_step using refl_trans_1n_trace_n1_ind => H_init /=.
  rewrite H_init.
  rewrite /step_m_init /= /pt_ext_map_net /=.
  rewrite pt_ext_init_handlers_fun_eq.
  exists [].  
  exact: RT1nTBase.
concludes.
rewrite H_init in H_step2 H_step1.
apply step_m_pt_ext_mapped_simulation_1 in H.
case: H => H.
  move: IHH_step1 => [tr' H_star].
  move: H => [tr'' H].
  exists (tr' ++ tr'').
  have H_trans := refl_trans_1n_trace_trans H_star.
  apply: H_trans.
  have ->: tr'' = tr'' ++ [] by rewrite -app_nil_end.
  apply: (@RT1nTStep _ _ _ _ (pt_ext_map_net x'')) => //.
  exact: RT1nTBase.
move: H => [H_eq H_eq'].
move: IHH_step1 => [tr' H_star].
exists tr'.
rewrite /pt_ext_map_net.
by rewrite H_eq H_eq'.
Qed.

Definition pt_ext_map_onet (onet : @ordered_network _ multi_fst) : @ordered_network _ multi_snd :=
mkONetwork (fun src dst => pt_map_msgs (onet.(onwPackets) (tot_map_name_inv src) (tot_map_name_inv dst)))
           (fun n => pt_ext_map_data (onet.(onwState) (tot_map_name_inv n)) (tot_map_name_inv n)).

Theorem step_o_pt_ext_mapped_simulation_1 :
  forall net net' tr,
    @step_o _ multi_fst net net' tr ->
    (exists tr', @step_o _ multi_snd (pt_ext_map_onet net) (pt_ext_map_onet net') tr') \/ (pt_ext_map_onet net' = pt_ext_map_onet net).
Proof.
move => net net' tr.
case => {net net' tr}.
- move => net net' m ms out d l from to H_eq H_hnd H_eq'.
  case H_m: (pt_map_msg m) => [m'|].
    left.
    case H_n: (net_handlers (tot_map_name to) (tot_map_name from) m' (pt_ext_map_data (onwState net to) to)) => [[out' d'] ps].
    exists [(tot_map_name to, inr out')].
    rewrite H_eq' /= /pt_ext_map_onet /=.
    apply (@SO_deliver _ _ _ _ m' (pt_map_msgs ms) _ (pt_ext_map_data d to) (pt_map_name_msgs l) (tot_map_name from)).
    * rewrite /= 2!tot_map_name_inv_inverse H_eq /=.
      case H_m0: pt_map_msg => [m0|]; last by rewrite H_m0 in H_m.
      rewrite H_m0 in H_m.
      by inversion H_m.
    * rewrite /= tot_map_name_inv_inverse.
      have H_q := @pt_ext_net_handlers_some _ _ _ _ _ _ _ multi_map_congr _ _ _ _ _ _ _ _ H_m H_n.
      rewrite /pt_ext_mapped_net_handlers /= in H_q.
      by repeat break_let; repeat tuple_inversion.
    * by rewrite /= pt_ext_map_update_eq collate_pt_map_update2_eq.
  right.
  have [H_eq_d H_ms] := pt_ext_net_handlers_none _ _ _ _ H_m H_hnd.
  rewrite H_eq' /pt_ext_map_onet /=.
  rewrite pt_ext_map_update_eq /= H_eq_d.
  rewrite collate_pt_map_eq H_ms /=.
  set nwS1 := update _ _ _.
  set nwS2 := fun n => pt_ext_map_data _ _.
  set nwP1 := fun _ _ => _. 
  set nwP2 := fun _ _ => _. 
  have H_eq_s: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 {nwS1 nwS2}.
    apply functional_extensionality => n.
    rewrite /update /=.
    case (name_eq_dec _ _) => H_dec //.
    by rewrite H_dec tot_map_name_inv_inverse.
  have H_eq_p: nwP1 = nwP2.
    rewrite /nwP1 /nwP2 /=.
    apply functional_extensionality => src.
    apply functional_extensionality => dst.
    rewrite /update2 /=.
    case (sumbool_and _ _ _ _) => H_dec //.
    move: H_dec => [H_eq_from H_eq_to].
    rewrite -H_eq_from -H_eq_to H_eq /=.
    case H_m': (pt_map_msg _) => [m'|] //.
    by rewrite H_m' in H_m.
  by rewrite H_eq_s H_eq_p.
- move => h net net' out inp d l H_hnd H_eq.
  case H_i: (pt_ext_map_input inp h (onwState net h)) => [inp'|].
    left.
    case H_h: (input_handlers (tot_map_name h) inp' (pt_ext_map_data (onwState net h) h)) => [[out' d'] ps].
    exists [(tot_map_name h, inl inp'); (tot_map_name h, inr out')].
    apply (@SO_input _ _ _ _ _ _ _ (pt_ext_map_data d h) (pt_map_name_msgs l)); last by rewrite H_eq /pt_ext_map_onet /= pt_ext_map_update_eq collate_pt_map_eq.
    rewrite /=.
    have H_q := @pt_ext_input_handlers_some _ _ _ _ _ _ _ multi_map_congr h inp (onwState net h) _ _ _ _ H_i H_h.
    rewrite /pt_ext_mapped_input_handlers /= in H_q.
    rewrite tot_map_name_inv_inverse.
    by repeat break_let; repeat tuple_inversion.
  right.
  rewrite /=.
  have [H_d H_l] := pt_ext_input_handlers_none h inp (onwState net h) H_i H_hnd.
  rewrite H_eq /= /pt_ext_map_onet /=.
  rewrite pt_ext_map_update_eq /= H_d.
  rewrite collate_pt_map_eq H_l /=.
  set nwS1 := update _ _ _.
  set nwS2 := fun n => pt_ext_map_data _ _.
  have H_eq_n: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 /=.
    apply functional_extensionality => n.
    rewrite /update /=.
    case (name_eq_dec _ _) => H_dec //.
    by rewrite H_dec tot_map_name_inv_inverse.
  by rewrite H_eq_n.
Qed.

Corollary step_o_pt_ext_mapped_simulation_star_1 :
  forall net tr,
    @step_o_star _ multi_fst step_o_init net tr ->
    exists tr', @step_o_star _ multi_snd step_o_init (pt_ext_map_onet net) tr'.
Proof.
move => net tr H_step.
remember step_o_init as y in *.
move: Heqy.
induction H_step using refl_trans_1n_trace_n1_ind => H_init /=.
  rewrite H_init.
  rewrite /step_o_init /= /pt_ext_map_net /=.
  rewrite pt_ext_init_handlers_fun_eq.
  exists [].  
  exact: RT1nTBase.
concludes.
rewrite H_init in H_step2 H_step1.
apply step_o_pt_ext_mapped_simulation_1 in H.
case: H => H.
  move: IHH_step1 => [tr' H_star].
  move: H => [tr'' H].
  exists (tr' ++ tr'').
  have H_trans := refl_trans_1n_trace_trans H_star.
  apply: H_trans.
  have ->: tr'' = tr'' ++ [] by rewrite -app_nil_end.
  apply: (@RT1nTStep _ _ _ _ (pt_ext_map_onet x'')) => //.
  exact: RT1nTBase.
move: H => [H_eq H_eq'].
move: IHH_step1 => [tr' H_star].
exists tr'.
by rewrite /pt_ext_map_onet H_eq H_eq'.
Qed.

Context {overlay_fst : NameOverlayParams multi_fst}.
Context {overlay_snd : NameOverlayParams multi_snd}.
Context {overlay_map_congr : NameOverlayParamsTotalMapCongruency overlay_fst overlay_snd name_map}.

Context {fail_msg_fst : FailMsgParams multi_fst}.
Context {fail_msg_snd : FailMsgParams multi_snd}.
Context {fail_msg_map_congr : FailMsgParamsPartialMapCongruency fail_msg_fst fail_msg_snd msg_map}.

Theorem step_o_f_pt_ext_mapped_simulation_1 :
  forall net net' failed failed' tr,
    @step_o_f _ _ overlay_fst fail_msg_fst (failed, net) (failed', net') tr ->
    (exists tr', @step_o_f _ _ overlay_snd fail_msg_snd (map tot_map_name failed, pt_ext_map_onet net) (map tot_map_name failed', pt_ext_map_onet net') tr') \/ (pt_ext_map_onet net' = pt_ext_map_onet net /\ failed = failed').
Proof.
move => net net' failed failed' tr H_step.
invcs H_step.
- case H_m: (pt_map_msg m) => [m'|].
    left.
    case H_n: (net_handlers (tot_map_name to) (tot_map_name from) m' (pt_ext_map_data (onwState net to) to)) => [[out' d'] ps].
    exists [(tot_map_name to, inr out')].
    rewrite /pt_ext_map_onet /=.
    apply (@SOF_deliver _ _ _ _ _ _ _ m' (pt_map_msgs ms) _ (pt_ext_map_data d to) (pt_map_name_msgs l) (tot_map_name from)).
    * rewrite /= 2!tot_map_name_inv_inverse /= H3 /=.
      case H_m0: (pt_map_msg _) => [m0|]; last by rewrite H_m in H_m0.
      rewrite H_m in H_m0.
      by inversion H_m0.
    * exact: not_in_failed_not_in.
    * rewrite /= tot_map_name_inv_inverse.
      have H_q := @pt_ext_net_handlers_some _ _ _ _ _ _ _ multi_map_congr _ _ _ _ _ _ _ _ H_m H_n.
      rewrite /pt_ext_mapped_net_handlers /= in H_q.
      by repeat break_let; repeat tuple_inversion.
    * by rewrite /= pt_ext_map_update_eq collate_pt_map_update2_eq.
  right.
  split => //.
  have [H_eq_d H_ms] := pt_ext_net_handlers_none _ _ _ _ H_m H6.
  rewrite /pt_ext_map_onet /= pt_ext_map_update_eq H_eq_d collate_pt_map_update2_eq H_ms /=.
  set nwP1 := update2 _ _ _ _.
  set nwS1 := update _ _ _.
  set nwP2 := fun _ _ => _.
  set nwS2 := fun _ => _.
  have H_eq_s: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 {nwS1 nwS2}.
    apply functional_extensionality => n.
    rewrite /update /=.
    case (name_eq_dec _ _) => H_dec //.
    by rewrite H_dec tot_map_name_inv_inverse.
  have H_eq_p: nwP1 = nwP2.
    rewrite /nwP1 /nwP2 /=.
    apply functional_extensionality => src.
    apply functional_extensionality => dst.
    rewrite /update2 /=.
    case (sumbool_and _ _ _ _) => H_dec //.
    move: H_dec => [H_eq_from H_eq_to].
    rewrite -H_eq_from -H_eq_to /= 2!tot_map_name_inv_inverse H3 /=.
    case H_m': (pt_map_msg _) => [m'|] //.
    by rewrite H_m' in H_m.
  by rewrite H_eq_s H_eq_p.
- case H_i: (pt_ext_map_input inp h (onwState net h)) => [inp'|].
    left.
    case H_h: (input_handlers (tot_map_name h) inp' (pt_ext_map_data (onwState net h) h)) => [[out' d'] ps].
    exists [(tot_map_name h, inl inp'); (tot_map_name h, inr out')].
    apply (@SOF_input _ _ _ _ _ _ _ _ _ _ (pt_ext_map_data d h) (pt_map_name_msgs l)).
    * exact: not_in_failed_not_in.
    * rewrite /= tot_map_name_inv_inverse.
      have H_q := @pt_ext_input_handlers_some _ _ _ _ _ _ _ multi_map_congr h inp (onwState net h) _ _ _ _ H_i H_h.
      rewrite /pt_ext_mapped_input_handlers /= in H_q.
      by repeat break_let; repeat tuple_inversion.
    * by rewrite /pt_ext_map_onet /= pt_ext_map_update_eq collate_pt_map_eq.
  right.
  rewrite /= /pt_ext_map_onet /=.
  have [H_d H_l] := pt_ext_input_handlers_none h inp (onwState net h) H_i H5.
  split => //.
  rewrite pt_ext_map_update_eq /= H_d.
  rewrite collate_pt_map_eq H_l /=.
  set nwS1 := update _ _ _.
  set nwS2 := fun n => pt_ext_map_data _ _.
  have H_eq_n: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 /=.
    apply functional_extensionality => n.
    rewrite /update /=.
    case (name_eq_dec _ _) => H_dec //.
    by rewrite H_dec tot_map_name_inv_inverse.
  by rewrite H_eq_n.
- left.
  rewrite /pt_ext_map_onet /=.  
  set l := map_pair _ _.
  have H_nd: NoDup (map (fun nm => fst nm) (pt_map_name_msgs l)).
    rewrite /pt_map_name_msgs /=.
    rewrite /l {l}.
    apply nodup_snd_fst.
      apply (@nodup_pt_map _ _ _ _ _ _ _ msg_fail); first exact: in_for_msg.
      apply nodup_map_pair.
      apply nodup_exclude.
      exact: no_dup_nodes.
    move => nm nm' H_in H_in'.
    by rewrite (pt_map_in_snd _ _ _ _ pt_fail_msg_fst_snd H_in) (pt_map_in_snd _ _ _ _ pt_fail_msg_fst_snd H_in').
  exists [].
  apply: SOF_fail => //.
  * exact: not_in_failed_not_in.
  * rewrite /=.
    rewrite /l collate_pt_map_eq /pt_map_name_msgs.
    by rewrite (nodup_perm_collate_eq _ _ H_nd (pt_map_map_pair_eq msg_fail h failed pt_fail_msg_fst_snd)).
Qed.

Corollary step_o_f_pt_ext_mapped_simulation_star_1 :
  forall net failed tr,
    @step_o_f_star _ _ overlay_fst fail_msg_fst step_o_f_init (failed, net) tr ->
    exists tr', @step_o_f_star _ _ overlay_snd fail_msg_snd step_o_f_init (map tot_map_name failed, pt_ext_map_onet net) tr'.
Proof.
move => net failed tr H_step.
remember step_o_f_init as y in *.
have H_eq_f: failed = fst (failed, net) by [].
have H_eq_n: net = snd (failed, net) by [].
rewrite H_eq_f {H_eq_f}.
rewrite {2}H_eq_n {H_eq_n}.
move: Heqy.
induction H_step using refl_trans_1n_trace_n1_ind => H_init /=.
  rewrite H_init.
  rewrite /step_o_f_init /= /pt_ext_map_onet /=.
  exists [].
  rewrite -pt_ext_init_handlers_fun_eq.
  exact: RT1nTBase.
concludes.
rewrite H_init {H_init x} in H_step2 H_step1.
case: x' H IHH_step1 H_step1 => failed' net'.
case: x'' H_step2 => failed'' net''.
rewrite /=.
move => H_step2 H IHH_step1 H_step1.
apply step_o_f_pt_ext_mapped_simulation_1 in H.
case: H => H.
  move: IHH_step1 => [tr' H_star].
  move: H => [tr'' H].
  exists (tr' ++ tr'').
  have H_trans := refl_trans_1n_trace_trans H_star.
  apply: H_trans.
  have ->: tr'' = tr'' ++ [] by rewrite -app_nil_end.
  apply: (@RT1nTStep _ _ _ _ (map tot_map_name failed'', pt_ext_map_onet net'')) => //.
  exact: RT1nTBase.  
move: H => [H_eq_n H_eq_f].
rewrite H_eq_n -H_eq_f.
move: IHH_step1 => [tr' H_star].
by exists tr'.
Qed.

Context {new_msg_fst : NewMsgParams multi_fst}.
Context {new_msg_snd : NewMsgParams multi_snd}.
Context {new_msg_map_congr : NewMsgParamsPartialMapCongruency new_msg_fst new_msg_snd msg_map}.

Definition pt_ext_map_odnet (net : @ordered_dynamic_network _ multi_fst) : @ordered_dynamic_network _ multi_snd :=
{| odnwNodes := map tot_map_name net.(odnwNodes) ;
   odnwPackets := fun src dst => pt_map_msgs (net.(odnwPackets) (tot_map_name_inv src) (tot_map_name_inv dst)) ;
   odnwState := fun n => match net.(odnwState) (tot_map_name_inv n) with
                         | None => None
                         | Some d => Some (pt_ext_map_data d (tot_map_name_inv n))
                         end |}.

Theorem step_o_d_f_pt_ext_mapped_simulation_1 :
  forall net net' failed failed' tr,
    NoDup (odnwNodes net) ->
    @step_o_d_f _ _ overlay_fst new_msg_fst fail_msg_fst (failed, net) (failed', net') tr ->
    (exists tr', @step_o_d_f _ _ overlay_snd new_msg_snd fail_msg_snd (map tot_map_name failed, pt_ext_map_odnet net) (map tot_map_name failed', pt_ext_map_odnet net') tr') \/ (pt_ext_map_odnet net' = pt_ext_map_odnet net /\ failed = failed').
Proof.
move => net net' failed failed' tr H_nd H_step.
invcs H_step.
- left.
  rewrite /pt_ext_map_odnet.
  exists [].
  apply (@SODF_start _ _ _ _ _ _ _ _ (tot_map_name h)) => /=; first exact: not_in_failed_not_in.
  set p1 := fun _ _ => _.
  set p2 := collate_ls _ _ _ _.
  set s1 := fun _ => _.
  set s2 := update_opt _ _ _.
  have H_eq_s: s1 = s2.
    rewrite /s1 /s2 /update_opt {s1 s2}.
    apply functional_extensionality => n.
    rewrite -pt_ext_init_handlers_eq.
    break_match_goal.
      break_if; break_if; try by congruence.
      - by repeat find_rewrite; repeat find_rewrite_lem tot_map_name_inv_inverse.
      - by find_reverse_rewrite; find_rewrite_lem tot_map_name_inverse_inv.
      - by find_rewrite.
    break_if; break_if; (try by congruence); last by find_rewrite.
    by repeat find_rewrite; repeat find_rewrite_lem tot_map_name_inv_inverse.
  rewrite H_eq_s /s2 {s1 s2 H_eq_s}.
  have H_eq_p: p1 = p2.
    rewrite /p1 /p2 {p1 p2}.    
    rewrite (collate_ls_pt_map_eq _ _ _ _ pt_new_msg_fst_snd) /=.
    rewrite collate_pt_map_eq.
    set f1 := fun _ _ => _.    
    set c1 := collate _ _ _.
    set c2 := collate _ _ _.
    set f'1 := map tot_map_name _.
    set f'2 := filter_rel (tot_map_name h) _.
    have H_c: c1 = c2.
      rewrite /c1 /c2 {c1 c2}.
      apply: nodup_perm_collate_eq; last first.
        rewrite /pt_map_name_msgs.
        apply: pt_nodup_perm_map_map_pair_perm => //.
        by rewrite pt_new_msg_fst_snd.
      rewrite /pt_map_name_msgs /=.
      apply: nodup_snd_fst => //.
        apply (@nodup_pt_map _ _ _ _  _ _ _ msg_new); first exact: in_for_msg.
        apply: nodup_map_pair.
        exact: nodup_exclude.
      move => nm nm' H_in H_in'.
      apply (@pt_map_in_snd _ _ _ _ _ _ _ msg_new _ _ _ _ pt_new_msg_fst_snd) in H_in.
      apply (@pt_map_in_snd _ _ _ _ _ _ _ msg_new _ _ _ _ pt_new_msg_fst_snd) in H_in'.
      by rewrite H_in H_in'.
    rewrite H_c {H_c}.
    suff H_suff: f'1 = f'2 by rewrite H_suff.
    rewrite /f'1 /f'2.
    elim (odnwNodes net) => //=.
    move => n ns IH.
    repeat break_if => //=.
    * by rewrite IH.
    * by find_apply_lem_hyp tot_adjacent_to_fst_snd.
    * by find_apply_lem_hyp not_in_failed_not_in.
    * by find_apply_lem_hyp tot_adjacent_to_fst_snd.
    * case: n0.
      exact: in_failed_in.  
  by rewrite H_eq_p.
- case H_m: (pt_map_msg m) => [m'|].
    left.
    case H_n: (net_handlers (tot_map_name to) (tot_map_name from) m' (pt_ext_map_data d to)) => [[out' d''] ps].
    exists [(tot_map_name to, inr out')].
    rewrite /pt_ext_map_onet /=.
    apply (@SODF_deliver _ _ _ _ _ _ _ _ m' (pt_map_msgs ms) _ (pt_ext_map_data d to) (pt_ext_map_data d' to) (pt_map_name_msgs l) (tot_map_name from)).
    * exact: not_in_failed_not_in.
    * exact: in_failed_in.
    * by rewrite /= tot_map_name_inv_inverse /= H5.
    * rewrite /= 2!tot_map_name_inv_inverse /=.
      find_rewrite.
      by rewrite /= H_m.
    * have H_q := @pt_ext_net_handlers_some _ _ _ _ _ _ _ multi_map_congr _ _ _ _ _ _ _ _ H_m H_n.
      rewrite /pt_ext_mapped_net_handlers /= in H_q.
      by repeat break_let; repeat tuple_inversion.
    * rewrite /= /pt_ext_map_odnet /=.
      set u1 := fun _ => match _ with | _ => _ end.
      set u2 := update_opt _ _ _.
      rewrite collate_pt_map_update2_eq.
      suff H_suff: u1 = u2 by rewrite H_suff.
      rewrite /u1 /u2 /update_opt /=.
      apply functional_extensionality => n.
      repeat break_if; try by congruence.
        rewrite -(tot_map_name_inverse_inv n) in n0.
        by rewrite e in n0.
      find_rewrite.
      by find_rewrite_lem tot_map_name_inv_inverse.
  right.
  split => //.
  have [H_eq_d H_ms] := pt_ext_net_handlers_none _ _ _ _ H_m H8.
  rewrite /pt_ext_map_odnet /= collate_pt_map_update2_eq H_ms /=.
  set nwP1 := update2 _ _ _ _.
  set nwS1 := fun _ => match _ with _ => _ end.
  set nwP2 := fun _ _ => _.
  set nwS2 := fun _ => _.
  have H_eq_s: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 {nwS1 nwS2}.
    apply functional_extensionality => n.
    rewrite /update_opt /=.
    break_if => //.
    find_rewrite.
    rewrite H5.
    by congruence.
  have H_eq_p: nwP1 = nwP2.
    rewrite /nwP1 /nwP2 /=.
    apply functional_extensionality => src.
    apply functional_extensionality => dst.
    rewrite /update2 /=.
    break_if => //.
    break_and.
    by rewrite -H -H0 2!tot_map_name_inv_inverse H6 /= H_m.
  by rewrite H_eq_s H_eq_p.
- case H_i: (pt_ext_map_input inp h d) => [inp'|].
    left.
    case H_h: (input_handlers (tot_map_name h) inp' (pt_ext_map_data d h)) => [[out' d''] ps].
    exists [(tot_map_name h, inl inp'); (tot_map_name h, inr out')].
    apply (@SODF_input _ _ _ _ _ _ _ _ _ _ _ (pt_ext_map_data d h) (pt_ext_map_data d' h) (pt_map_name_msgs l)).
    * exact: not_in_failed_not_in.
    * exact: in_failed_in. 
    * by rewrite /pt_ext_map_odnet /= tot_map_name_inv_inverse H5.
    * have H_q := @pt_ext_input_handlers_some _ _ _ _ _ _ _ multi_map_congr h inp d _ _ _ _ H_i H_h.
      rewrite /pt_ext_mapped_input_handlers /= in H_q.
      rewrite H7 in H_q.
      by repeat tuple_inversion.
    * rewrite /= /pt_ext_map_odnet /= collate_pt_map_eq.
      set u1 := fun _ => match _ with | _ => _ end.
      set u2 := update_opt _ _ _.
      suff H_suff: u1 = u2 by rewrite H_suff.
      rewrite /u1 /u2 /update_opt /=.
      apply functional_extensionality => n.
      repeat break_if; try by congruence.
        rewrite -(tot_map_name_inverse_inv n) in n0.
        by rewrite e in n0.
      find_rewrite.
      by find_rewrite_lem tot_map_name_inv_inverse.
  right.
  rewrite /= /pt_ext_map_odnet /=.
  have [H_d H_l] := pt_ext_input_handlers_none h inp d H_i H7.
  split => //=.
  rewrite collate_pt_map_eq H_l /=.
  set nwS1 := fun n : name => match _ with | _ => _ end.
  set nwS2 := fun n : name => match _ with | _ => _ end.
  have H_eq_n: nwS1 = nwS2.
    rewrite /nwS1 /nwS2 /=.
    apply functional_extensionality => n.
    rewrite /update_opt /=.
    break_if => //.
    by repeat find_rewrite.
  by rewrite H_eq_n.
- left.
  rewrite /pt_ext_map_odnet /=.
  set l := map_pair _ _.
  have H_nd': NoDup (map (fun nm => fst nm) (pt_map_name_msgs l)).
    rewrite /pt_map_name_msgs /=.
    rewrite /l {l}.
    apply nodup_snd_fst.
      apply (@nodup_pt_map _ _ _ _ _  _ _ msg_fail); first exact: in_for_msg.
      apply nodup_map_pair.
      exact: nodup_exclude.
    move => nm nm' H_in H_in'.
    by rewrite (pt_map_in_snd  _ _ _ _ pt_fail_msg_fst_snd H_in) (pt_map_in_snd _ _ _ _ pt_fail_msg_fst_snd H_in').
  exists [].
  apply: SODF_fail => //.
  * exact: not_in_failed_not_in.
  * exact: in_failed_in.
  * rewrite /=.
    rewrite /l collate_pt_map_eq.
    have H_pm := pt_nodup_perm_map_map_pair_perm _ h failed H_nd (Permutation_refl (map tot_map_name (odnwNodes net))) pt_fail_msg_fst_snd.
    have H_pm' := H_pm _ _ _ _ name_map_bijective _ _ overlay_map_congr _ _ fail_msg_map_congr.
    have H_eq := nodup_perm_collate_eq  _ _ H_nd' H_pm'.
    by rewrite H_eq.
Qed.

Corollary step_o_d_f_pt_ext_mapped_simulation_star_1 :
  forall net failed tr,
    @step_o_d_f_star _ _ overlay_fst new_msg_fst fail_msg_fst step_o_d_f_init (failed, net) tr ->
    exists tr', @step_o_d_f_star _ _ overlay_snd new_msg_snd fail_msg_snd step_o_d_f_init (map tot_map_name failed, pt_ext_map_odnet net) tr'.
Proof.
move => net failed tr H_step.
remember step_o_d_f_init as y in *.
change failed with (fst (failed, net)).
change net with (snd (failed, net)) at 2.
move: Heqy.
induction H_step using refl_trans_1n_trace_n1_ind => H_init /=.
  rewrite H_init /step_o_d_f_init /= /step_o_init.
  exists [].
  exact: RT1nTBase.
concludes.
rewrite H_init {H_init x} in H_step2 H_step1.
case: x' H IHH_step1 H_step1 => failed' net'.
case: x'' H_step2 => failed'' net''.
rewrite /=.
move => H_step2 H IHH_step1 H_step1.
find_apply_lem_hyp step_o_d_f_pt_ext_mapped_simulation_1; last by move: H_step1; apply: ordered_dynamic_nodes_no_dup.
case: H => H.
  move: IHH_step1 => [tr' H_star].
  move: H => [tr'' H].
  exists (tr' ++ tr'').
  have H_trans := refl_trans_1n_trace_trans H_star.
  apply: H_trans.
  have ->: tr'' = tr'' ++ [] by rewrite -app_nil_end.
  apply: (@RT1nTStep _ _ _ _ (map tot_map_name failed'', pt_ext_map_odnet net'')) => //.
  exact: RT1nTBase.  
move: H => [H_eq_n H_eq_f].
rewrite H_eq_n -H_eq_f.
move: IHH_step1 => [tr' H_star].
by exists tr'.
Qed.

End PartialExtendedMapSimulations.
