xquery version "1.0-ml";

module namespace parser = "http://marklogic.com/mljson/query-parser";

import module namespace prop="http://xqdev.com/prop" at "properties.xqy";
import module namespace json="http://marklogic.com/json" at "json.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare private variable $GROUPING-INDEX as xs:integer := 0;


declare function parser:parse(
	$query as xs:string
) as cts:query?
{
	let $init := xdmp:set($GROUPING-INDEX, 0)
	let $tokens := parser:tokenize($query)
	let $grouped := parser:groupTokens($tokens, 1)
	let $folded := parser:foldTokens(<group>{ $grouped }</group>, ("not", "or", "and", "near"))
	return parser:dispatchQueryTree($folded)
};

declare private function parser:tokenize(
	$query as xs:string
) as element()*
{
	let $phraseMatch := '"[^"]+"'
	let $wordMatch := "[\w,\*\?][\w\-,\*\?]*"
	let $constraintMatch := "[A-Za-z_\-]+:"
	let $tokens := (
		"\(", "\)", $phraseMatch,
		"\-", " AND ", " OR ", " NEAR ", " NEAR/\d+ ",
		concat($constraintMatch, $phraseMatch, "|", $constraintMatch, $wordMatch),
		$wordMatch, "\s+"
	)

	let $regex := string-join(for $t in $tokens return concat("(", $t, ")"), "|")
	for $match in analyze-string($query, $regex)/*
	return
		if($match/self::*:non-match) then <error>{ string($match) }</error>
		else if($match/*:group/@nr = 1) then <startgroup/>
		else if($match/*:group/@nr = 2) then <endgroup/>
		else if($match/*:group/@nr = 3) then <phrase>{
				let $value := string($match)
				return substring($value, 2, string-length($value) - 2)
			}</phrase>
		else if($match/*:group/@nr = 4) then <not/>
		else if($match/*:group/@nr = 5) then <and/>
		else if($match/*:group/@nr = 6) then <or/>
		else if($match/*:group/@nr = 7) then <near/>
		else if($match/*:group/@nr = 8) then <near distance="{ xs:double(tokenize(string($match), "/")[2]) }"/>
		else if($match/*:group/@nr = 9) then <constraint>{
				let $bits := tokenize($match, ":")
				return (
					<field>{ $bits[1] }</field>,
					<value>{ string-join($bits[2 to last()], ":") }</value>
				)
			}</constraint>
		else if($match/*:group/@nr = 10) then <term>{ string($match) }</term>
		else if($match/*:group/@nr = 11) then <whitespace>{ string($match) }</whitespace>

		else <error>{ string($match) }</error>
};

declare private function parser:groupTokens(
	$tokens as element()*,
	$starting-index as xs:integer
) as element()*
{
	let $continue := true()
	for $token at $index in $tokens[$starting-index to count($tokens)]
	let $index := $starting-index + $index - 1
	where $continue and $index > $GROUPING-INDEX
	return (
		xdmp:set($GROUPING-INDEX, $GROUPING-INDEX + 1)
		,
		if(local-name($token) = "startgroup")
		then <group>{ parser:groupTokens($tokens, $index + 1) }</group>
		else if(local-name($token) = "endgroup")
		then
			if($starting-index > 1)
			then xdmp:set($continue, false())
			else ()
		else $token
	)
};

declare private function parser:foldTokens(
	$group as element(group),
	$order as xs:string*
) as element(group)
{
	let $order :=
		for $operator in $order
		where exists($group//*[local-name(.) = $operator])
		return $operator
	let $newGroup :=
		<group>{
			let $nextIndex := 1
			let $foundOne := false()
			let $tokens := $group/*
			for $token at $index in $tokens
			let $nextName := local-name($tokens[$index + 1])
			where $index = $nextIndex
			return (
				xdmp:set($nextIndex, $nextIndex + 1),

				if($order[1] = "and" and $nextName = "and" and $foundOne = false())
				then (
					parser:extractSequence($tokens, "and", $index, $order),
					xdmp:set($foundOne, true()),
					xdmp:set($nextIndex, $index + 3)
				)
				else if($order[1] = "or" and $nextName = "or" and $foundOne = false())
				then (
					parser:extractSequence($tokens, "or", $index, $order),
					xdmp:set($foundOne, true()),
					xdmp:set($nextIndex, $index + 3)
				)
				else if($order[1] = "not" and local-name($token) = "not" and $foundOne = false())
				then (
					<notQuery>{ parser:foldIfNeeded($tokens[$index + 1], $order) }</notQuery>,
					xdmp:set($foundOne, true()),
					xdmp:set($nextIndex, $index + 2)
				)
				else if($order[1] = "near" and $nextName = "near" and $foundOne = false())
				then (
					parser:extractSequence($tokens, "near", $index, $order),
					xdmp:set($foundOne, true()),
					xdmp:set($nextIndex, $index + 3)
				)
				else if(local-name($token) = "group")
				then parser:foldTokens($token, $order)
				else $token
			)
		}</group>
	return
		if(exists($newGroup//(and, or, not, near)))
		then parser:foldTokens($newGroup, $order)
		else $newGroup
};

declare private function parser:foldIfNeeded(
	$token as element(),
	$order as xs:string*
) as element()
{
	if(local-name($token) = "group")
	then parser:foldTokens($token, $order)
	else $token
};

declare private function parser:extractSequence(
	$tokens as element()*,
	$operator as xs:string,
	$index as xs:integer,
	$order as xs:string*
) as element()
{
	element { concat($operator, "Query") } {(
		if(local-name($tokens[$index]) = concat($operator, "Query"))
		then ($tokens[$index]/@*, $tokens[$index]/*)
		else ($tokens[$index + 1]/@*, parser:foldIfNeeded($tokens[$index], $order))
		,
		parser:foldIfNeeded($tokens[$index + 2], $order)
	)}
};


declare private function parser:dispatchQueryTree(
	$token as element()
) as cts:query*
{
	let $queries :=
		for $term in $token/*
		return parser:termToQuery($term)
	return
		if(count($queries) = 1 or local-name($token) = ("andQuery", "orQuery"))
		then $queries
		else cts:and-query($queries)
};

declare private function parser:termToQuery(
	$term as element()
) as cts:query?
{
	typeswitch ($term)
	case element(andQuery) return cts:and-query(parser:dispatchQueryTree($term))
	case element(orQuery) return cts:or-query(parser:dispatchQueryTree($term))
	case element(notQuery) return parser:notQuery($term)
	case element(nearQuery) return parser:nearQuery($term)
	case element(constraint) return parser:constraintQuery($term)
	case element(term) return parser:wordQuery($term)
	case element(phrase) return parser:wordQuery($term)
	case element(group) return parser:dispatchQueryTree($term)
	case element(whitespace) return ()

	default return xdmp:log(concat("Unhandled query token: ", xdmp:quote($term)))
};

declare private function parser:wordQuery(
	$term as element()
) as cts:query
{
	cts:word-query(string($term))
};

declare private function parser:notQuery(
	$term as element(notQuery)
) as cts:not-query
{
	cts:not-query(parser:dispatchQueryTree($term))
};

declare private function parser:nearQuery(
	$term as element(notQuery)
) as cts:query
{
	cts:near-query(parser:dispatchQueryTree($term), $term/@distance)
};

declare private function parser:constraintQuery(
	$term as element(constraint)
) as cts:query
{
    (:
        bits:
            field -> field, name
            range -> range, name, key, type, operator
            map -> map, name, key, mode
    :)
    let $value := string($term/value)
    let $definition := prop:get(concat("index-", $term/field))
    let $bits := tokenize($definition, "/")
    return
        if($bits[1] = "field")
        then cts:field-word-query($bits[2], $value)
        else if($bits[1] = "map")
        then 
            if($bits[4] = "equals")
            then cts:element-value-query(xs:QName(concat("json:", $bits[3])), $value)
            else cts:element-word-query(xs:QName(concat("json:", $bits[3])), $value)
        else if($bits[1] = "range")
        then
            let $value :=
                if($bits[4] = "number" and $value castable as xs:decimal)
                then xs:decimal($value)
                (: XXX - need to do something for dates when we have them supported as a type :)
                else $value
            let $QName := xs:QName(concat("json:", $bits[3]))
            let $operator :=
                if($bits[5] = "eq")
                then "="
                else if($bits[5] = "ne")
                then "!="
                else if($bits[5] = "lt")
                then "<"
                else if($bits[5] = "le")
                then "<="
                else if($bits[5] = "gt")
                then ">"
                else if($bits[5] = "ge")
                then ">="
                else "="
            return cts:element-range-query($QName, $operator, $value, "collation=http://marklogic.com/collation/")
        else parser:wordQuery(<term>{ concat($term/field, ":", $value) }</term>)
};

declare private function parser:treeToString(
	$tree as element()
) as xs:string
{
	typeswitch ($tree)
	case element(andQuery) return string-join(for $i in $tree/* return parser:treeToString($i), " AND ")
	case element(orQuery) return string-join(for $i in $tree/* return parser:treeToString($i), " OR ")
	case element(notQuery) return concat("-", parser:treeToString($tree/*[1]))
	case element(nearQuery) return
		let $near := if(exists($tree/@distance)) then concat(" NEAR/", $tree/@distance, " ") else " NEAR "
		return string-join(for $i in $tree/* return parser:treeToString($i), $near)
	case element(constraint) return concat($tree/field, ":", $tree/value)
	case element(term) return string($tree)
	case element(phrase) return concat('"', string($tree), '"')
	case element(group) return concat("(", for $i in $tree/* return parser:treeToString($i), ")")
	case element(whitespace) return " "

	default return xdmp:log(concat("Unhandled token: ", xdmp:quote($tree)))
};
