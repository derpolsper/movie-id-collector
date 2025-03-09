#!/bin/sh

# Given any IMDB ID, script creates a xml with database identifiers
# as metadata inside the Matroska container to identify the movie.
# Uses wikidata.org as a source for various databases.

validate_imdb_id() {
    input="$1"
    imdb_id=""

    case "$input" in
        tt[0-9][0-9][0-9][0-9][0-9][0-9][0-9]|tt[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
            imdb_id="$input"
            ;;
        *imdb.com/title/tt[0-9][0-9][0-9][0-9][0-9][0-9][0-9]*)
            imdb_id=$(echo "$input" | sed -n 's/.*imdb\.com\/title\/\(tt[0-9]\{7,8\}\).*/\1/p')
            ;;
        *)
            return 1
            ;;
    esac

    echo "$imdb_id"
    return 0
}

query_wikidata() {
    imdb_id="$1"
    query="
SELECT DISTINCT ?item ?type ?imdb ?academy ?allmovie ?bfi ?lc ?tcm ?tmdb ?tvdb ?filmaffinity ?netflix ?ofdb ?plex ?title ?date WHERE {
  VALUES ?imdb_id { \"$imdb_id\" }
  ?item wdt:P345 ?imdb_id;
        wdt:P31 ?type.

  # Get all IDs using statement paths
  OPTIONAL { ?item wdt:P345 ?imdb }         # IMDB ID
  OPTIONAL { ?item wdt:P10056 ?academy }    # Academy Awards Database film ID
  OPTIONAL { ?item wdt:P2603 ?allmovie }    # AllMovie title ID
  OPTIONAL { ?item wdt:P2703 ?bfi }         # BFI Films, TV and people ID
  OPTIONAL { ?item wdt:P244 ?lc }           # Library of Congress authority ID
  OPTIONAL { ?item wdt:P4276 ?tcm }         # TCM Movie Database film ID
  OPTIONAL { ?item wdt:P4947 ?tmdb }        # TMDB ID
  OPTIONAL { ?item wdt:P12196 ?tvdb }       # TVDB movie ID
  OPTIONAL { ?item wdt:P480 ?filmaffinity } # FilmAffinity ID
  OPTIONAL { ?item wdt:P1874 ?netflix }     # Netflix ID
  OPTIONAL { ?item wdt:P3138 ?ofdb }        # OFDb ID
  OPTIONAL { ?item wdt:P11460 ?plex }       # Plex media key

  # Get labels and dates
  OPTIONAL { 
    ?item rdfs:label ?title.
    FILTER(LANG(?title) = \"en\")
  }
  OPTIONAL { ?item wdt:P577 ?date }

  SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". }
}"

    # Get the results
    result=$(curl -G -H "Accept: application/json" \
        "https://query.wikidata.org/sparql" \
        --data-urlencode "query=$query" \
        --data-urlencode "format=json" 2>/dev/null)

    # If no TVDB ID found in the main query, try a direct lookup
    if ! echo "$result" | jq -e '.results.bindings[0].tvdb' >/dev/null; then
        # Get the Wikidata ID
        wikidata_id=$(echo "$result" | jq -r '.results.bindings[0].item.value' | sed 's|.*/||')

        # Try a direct lookup for TVDB movie ID
        tvdb_query="
SELECT ?tvdb WHERE {
  wd:$wikidata_id p:P12196 ?statement.
  ?statement ps:P12196 ?tvdb.
}"

        tvdb_result=$(curl -G -H "Accept: application/json" \
            "https://query.wikidata.org/sparql" \
            --data-urlencode "query=$tvdb_query" \
            --data-urlencode "format=json" 2>/dev/null)

        # If we found a TVDB ID, add it to the main result
        tvdb_id=$(echo "$tvdb_result" | jq -r '.results.bindings[0].tvdb.value // empty')
        if [ -n "$tvdb_id" ]; then
            result=$(echo "$result" | jq --arg tvdb "$tvdb_id" \
                '.results.bindings[0].tvdb = {"type": "literal", "value": $tvdb} | {results: {bindings: [.]}}')
        fi
    fi

    echo "$result"
}

process_response() {
    json="$1"

    if ! echo "$json" | jq -e '.results.bindings[0]' >/dev/null; then
        echo "Error: No results found for this IMDB ID" >&2
        return 1
    fi

    type_uri=$(echo "$json" | jq -r '.results.bindings[0].type.value')

    case "$type_uri" in
        *"Q11424"*)
            process_movie_response "$json"
            ;;
        *"Q5398426"*)
            echo "Error: This IMDB ID refers to a TV series. This script only processes movies." >&2
            echo "Hint: For TV series, you would need the IMDB ID of a specific movie, not a TV show." >&2
            return 1
            ;;
        *"Q3464665"*)
            echo "Error: This IMDB ID refers to a TV season. This script only processes movies." >&2
            echo "Hint: For TV content, you would need the IMDB ID of a specific movie, not a TV season." >&2
            return 1
            ;;
        *"Q21191270"*)
            echo "Error: This IMDB ID refers to a TV episode. This script only processes movies." >&2
            echo "Hint: For TV content, you would need the IMDB ID of a specific movie, not a TV episode." >&2
            return 1
            ;;
        *)
            echo "Error: This IMDB ID does not refer to a movie" >&2
            echo "This script only processes movies. Please provide an IMDB ID for a movie." >&2
            return 1
            ;;
    esac
}

process_movie_response() {
    json="$1"
    imdb=$(echo "$json" | jq -r '.results.bindings[0].imdb.value // empty')
    tmdb=$(echo "$json" | jq -r '.results.bindings[0].tmdb.value // empty')
    tvdb=$(echo "$json" | jq -r '.results.bindings[0].tvdb.value // empty')
    academy=$(echo "$json" | jq -r '.results.bindings[0].academy.value // empty')
    allmovie=$(echo "$json" | jq -r '.results.bindings[0].allmovie.value // empty')
    bfi=$(echo "$json" | jq -r '.results.bindings[0].bfi.value // empty')
    filmaffinity=$(echo "$json" | jq -r '.results.bindings[0].filmaffinity.value // empty')
    lc=$(echo "$json" | jq -r '.results.bindings[0].lc.value // empty')
    netflix=$(echo "$json" | jq -r '.results.bindings[0].netflix.value // empty')
    ofdb=$(echo "$json" | jq -r '.results.bindings[0].ofdb.value // empty')
    plex=$(echo "$json" | jq -r '.results.bindings[0].plex.value // empty')
    tcm=$(echo "$json" | jq -r '.results.bindings[0].tcm.value // empty')
    title=$(echo "$json" | jq -r '.results.bindings[0].title.value // empty')

    # Extract year from date
    date=$(echo "$json" | jq -r '.results.bindings[0].date.value // empty')
    if [ -n "$date" ]; then
        year=$(echo "$date" | cut -d'-' -f1)
    fi

    if [ -z "$title" ] || [ -z "$year" ]; then
        echo "Error: Could not find title or year for the movie" >&2
        return 1
    fi

    filename=$(sanitize_filename "$title" "$year")
    generate_movie_xml "$imdb" "$tmdb" "$tvdb" "$academy" "$allmovie" "$bfi" "$filmaffinity" "$lc" "$netflix" "$ofdb" "$plex" "$tcm" "$filename.xml"
    echo "XML written to: $filename.xml" >&2
}

generate_movie_xml() {
    imdb="$1"
    tmdb="$2"
    tvdb="$3"
    academy="$4"
    allmovie="$5"
    bfi="$6"
    filmaffinity="$7"
    lc="$8"
    netflix="$9"
    ofdb="${10}"
    plex="${11}"
    tcm="${12}"
    output_file="${13}"

    printf '%s\n' \
        '<?xml version="1.0" encoding="UTF-8"?>' \
        '<!DOCTYPE Tags SYSTEM "matroskatags.dtd">' \
        '<Tags>' \
        '    <Tag> <!-- Movie -->' \
        '        <Targets>' \
        '            <TargetTypeValue>50</TargetTypeValue>' \
        '        </Targets>' \
        '        <Simple>' \
        '            <Name>IMDB</Name>' \
        "            <String>$imdb</String>" \
        '        </Simple>' \
        > "$output_file"

    if [ -n "$tmdb" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>TMDB</Name>' \
            "            <String>movie/$tmdb</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$tvdb" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>TVDB</Name>' \
            "            <String>movie/$tvdb</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$academy" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>Academy</Name>' \
            "            <String>$academy</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$allmovie" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>AllMovie</Name>' \
            "            <String>$allmovie</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$bfi" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>BFI</Name>' \
            "            <String>$bfi</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$filmaffinity" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>FilmAffinity</Name>' \
            "            <String>$filmaffinity</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$lc" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>LibraryOfCongress</Name>' \
            "            <String>$lc</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$netflix" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>Netflix</Name>' \
            "            <String>$netflix</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$ofdb" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>OFDb</Name>' \
            "            <String>$ofdb</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$plex" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>Plex</Name>' \
            "            <String>$plex</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    if [ -n "$tcm" ]; then
        printf '%s\n' \
            '        <Simple>' \
            '            <Name>TCM</Name>' \
            "            <String>$tcm</String>" \
            '        </Simple>' \
            >> "$output_file"
    fi

    printf '%s\n' \
        '    </Tag>' \
        '</Tags>' \
        >> "$output_file"
}

sanitize_filename() {
    title="$1"
    year="$2"

    # Replace spaces with dots and remove special characters
    clean_title=$(echo "$title" | tr ' ' '.' | tr -cd '[:alnum:].-')
    echo "${clean_title}.${year}"
}

main() {
    imdb_id=""

    if [ $# -eq 0 ]; then
        echo "Please enter an IMDB ID or URL (format: tt1234567 or IMDB URL):" >&2
        read input
        imdb_id=$(validate_imdb_id "$input")
    else
        imdb_id=$(validate_imdb_id "$1")
    fi

    if [ -z "$imdb_id" ]; then
        echo "Error: Invalid IMDB ID format. Please use 'tt' followed by 7-8 digits (e.g., tt0123456)" >&2
        return 1
    fi

    result=$(query_wikidata "$imdb_id")
    process_response "$result"
}

# Check for required commands
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found. Please install it." >&2
        exit 1
    fi
done

# Only run if not being sourced
case "$0" in
    */sh|*/bash) ;;
    *) main "$@" ;;
esac 