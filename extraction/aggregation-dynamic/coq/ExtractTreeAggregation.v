Require Import Verdi.Verdi.
Require Import Verdi.NameOverlay.

Require Import AggregationDefinitions.
Require Import TreeAux.
Require Import TreeAggregationDynamic.

Require Import StructTact.Fin.

Require Import mathcomp.ssreflect.ssreflect.
Require Import mathcomp.ssreflect.ssrfun.
Require Import mathcomp.ssreflect.fintype.

Require Import mathcomp.fingroup.fingroup.

Require Import mathcomp.algebra.zmodp.

Require Import ExtrOcamlBasic.
Require Import ExtrOcamlNatInt.
Require Import ExtrOcamlString.

Require Import ExtrOcamlBasicExt.
Require Import ExtrOcamlNatIntExt.

Require Import ExtrOcamlBool.
Require Import ExtrOcamlList.
Require Import ExtrOcamlFin.

Module NumNames : NatValue. Definition n := 3. End NumNames.
Module Names := FinName NumNames.
Module NamesOT := FinNameOrderedType NumNames Names.
Module NamesOTCompat := FinNameOrderedTypeCompat NumNames Names.
Module RootNames := FinRootNameType NumNames Names.
Module AdjacentNames := FinCompleteAdjacentNameType NumNames Names.

Require Import MSetList.
Module NamesSet <: MSetInterface.S := MSetList.Make NamesOT.

Require Import FMapList.
Module NamesMap <: FMapInterface.S := FMapList.Make NamesOTCompat.

Module CFG <: CommutativeFinGroup.
Definition gT := Zp_finGroupType 127.
Lemma mulgC : @commutative gT _ mulg. exact: Zp_mulgC. Qed.
End CFG.

Module TAuxNames := NameTypeTAux Names NamesOT NamesSet NamesOTCompat NamesMap.

Module ADefNames := NameTypeADefs Names NamesOT NamesSet NamesOTCompat NamesMap CFG.

Module TreeAggregationNames := TreeAggregation Names NamesOT NamesSet NamesOTCompat NamesMap RootNames CFG AdjacentNames TAuxNames ADefNames.
Import TreeAggregationNames.

Extraction "extraction/aggregation-dynamic/ocaml/TreeAggregation.ml" List.seq TreeAggregation_BaseParams TreeAggregation_MultiParams.
