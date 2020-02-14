module Rte.Marks exposing (..)

import Rte.Model exposing (EditorBlockNode, EditorInlineLeaf(..), Mark, NodePath)
import Rte.NodeUtils exposing (EditorNode(..), NodeResult(..), findNode, replaceNode)


selectionMark : Mark
selectionMark =
    { name = "selection", attributes = [] }


selectableMark : Mark
selectableMark =
    { name = "selectable", attributes = [] }


findMarksFromInlineLeaf : EditorInlineLeaf -> List Mark
findMarksFromInlineLeaf leaf =
    case leaf of
        TextLeaf l ->
            l.marks

        InlineLeaf l ->
            l.marks


toggleMarkAtPath : ToggleAction -> Mark -> NodePath -> EditorBlockNode -> Result String EditorBlockNode
toggleMarkAtPath action mark path node =
    case findNode path node of
        BlockNodeResult blockNode ->
            let
                parameters =
                    blockNode.parameters

                newBlock =
                    { blockNode | parameters = { parameters | marks = toggleMark action mark parameters.marks } }
            in
            replaceNode path (BlockNodeWrapper newBlock) node

        InlineLeafResult inlineLeaf ->
            case inlineLeaf of
                TextLeaf l ->
                    let
                        newLeaf =
                            { l | marks = toggleMark action mark l.marks }
                    in
                    replaceNode path (InlineLeafWrapper (TextLeaf newLeaf)) node

                InlineLeaf l ->
                    let
                        newLeaf =
                            { l | marks = toggleMark action mark l.marks }
                    in
                    replaceNode path (InlineLeafWrapper (InlineLeaf newLeaf)) node

        NoResult ->
            Err "No block found at path"


type ToggleAction
    = Add
    | Remove
    | Flip


toggleMark : ToggleAction -> Mark -> List Mark -> List Mark
toggleMark toggleAction mark marks =
    let
        isMember =
            List.any (\m -> m.name == mark.name) marks
    in
    if toggleAction == Remove || (toggleAction == Flip && isMember) then
        List.filter (\x -> x.name /= mark.name) marks

    else if not isMember then
        List.sortBy (\m -> m.name) (mark :: marks)

    else
        marks
