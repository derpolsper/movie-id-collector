Filenames are a poor way to identify media. Ideally, movies and TV show episodes files should be parsed for meta-data by players as they do for music.
It is basically to give a precise clue about what this file is about to automated software organizing media libraries (Media Centers, Media Players, your Set Top Box, your TV, your trakt plugin, etc.).
Plex users knows it well; bad matches happens, and is a pain to manually edit across hundreds of movies or shows. The more this usage is prevalent, the more automated software will parse it, everybody wins. Music does it, why can't we?

We also like to provide multiple database ID for media centers/media player developers to choose from, as their API are not equally accessible, their content differs and artworks too. Also, as some mediaDB services died in the past, we shouldn't rely on only one way to identify the releases that are meant to exist for a long time.

The Matroska container uses a compact markup format for tags called EBML, that is an binary form of XML. To ease the process of importing this structured data, mkvmerge/mkvpropedit can read matroska XML documents and convert them to fit in MKV header. MKV suggest a list of standard tag names, however, any string can be used as a key in the tag name field.

This script reads an IMDB ID and sends api requests to wikidata.org for several more mediaDB IDs and puts them in a matroska XML file.

To get IDs for say *Star Trek (2009) by J.J. Abrams*, run the script:

	movie-id-collector.sh http://www.imdb.com/title/tt0796366/

the resulting XML will be Star.Trek.2009.xml

	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE Tags SYSTEM "matroskatags.dtd">
	<Tags>
	<Tag> <!-- Movie -->
	<Targets>
	<TargetTypeValue>50</TargetTypeValue>
	</Targets>
	<Simple>
	<Name>IMDB</Name>
	<String>tt0796366</String>
	</Simple>
	<Simple>
	<Name>TMDB</Name>
	<String>movie/13475</String>
	</Simple>
	<Simple>
	<Name>TVDB</Name>
	<String>movie/583</String>
	</Simple>
	<Simple>
	<Name>AllMovie</Name>
	<String>255129</String>
	</Simple>
	<Simple>
	<Name>BFI</Name>
	<String>150735921</String>
	</Simple>
	<Simple>
	<Name>FilmAffinity</Name>
	<String>138466</String>
	</Simple>
	<Simple>
	<Name>LibraryOfCongress</Name>
	<String>no2009083143</String>
	</Simple>
	<Simple>
	<Name>Netflix</Name>
	<String>70101276</String>
	</Simple>
	<Simple>
	<Name>OFDb</Name>
	<String>163394</String>
	</Simple>
	<Simple>
	<Name>Plex</Name>
	<String>5d77683aeb5d26001f1e1cf3</String>
	</Simple>
	<Simple>
	<Name>TCM</Name>
	<String>89204</String>
	</Simple>
	</Tag>
	</Tags>

Other movies are not that well represented and the resulting XML will have a shorter list of IDs.
