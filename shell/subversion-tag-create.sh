#!/bin/ksh

##helpers
function die {
        echo -e $@
        exit 1
}

##variables
SVN_REPOSITORY=${SVN_REPOSITORY:-"https://subversion.tecgraf.puc-rio.br/engdist"}
SVN_URL=${SVN_URL:-"$SVN_REPOSITORY/openbus"}
# space separated filenames
FILES_TO_PARSE="core/services/version.h"
# assuming trunk version
FROM_VERSION_ID="OB_HEAD"
NEW_VERSION_ID=
TEMP_DIR=/tmp/openbus-tag-creation

function print_usage {
	echo "Usage: $0 <old branch> <new branch> [--url svn://myserver/mydir/project]"
	echo "By default, this script will consider the following subversion URL: $SVN_PROJECTURL"
	echo "To change it, you have to edit this script!"
	exit 0
}

####sanity checks
if [ -n "$1" ] && [ -n "$2" ]; then
	if [ "$1" == "--url" ] || [ "$2" == "--url" ]; then print_usage; fi
	if [ "$3" == "--url" ] && [ -n "$4" ]; then
		SVN_URL=$4
	fi
	FROM="$1"
	NEW="$2"
	is_tag_or_branch=`echo $FROM |egrep -e "tags|branches" `
        if [ "$?" == "0" ]; then
		FROM_VERSION_ID=`echo $FROM|cut -d/ -f2`
	fi 
	NEW_VERSION_ID=`echo $NEW|cut -d/ -f2`
	echo "INFO: Using the following subversion path: $SVN_URL"
	echo "INFO: We'll copy the branch [$FROM] to a new one [$NEW]"
	echo "INFO: We'll replace string [$FROM_VERSION_ID] with [$NEW_VERSION_ID] in files: $FILES_TO_PARSE"
	echo "Press ENTER to continue or CTRL+C to abort"
	read
else
	print_usage
fi

### main
mkdir -p $TEMP_DIR || die "ERROR: Could not create directory $TEMP_DIR"
svn co $SVN_URL $TEMP_DIR/ || die "ERROR: Subversion checkout has failed: [$SVN_URL]"

cd $TEMP_DIR
svn cp $FROM $NEW || die "ERROR: Problem while creating the new branch"

for each in `echo $FILES_TO_PARSE`
do
	echo "INFO: Parsing file [$NEW/$each] to replace any version string"
	sed -i "s/$FROM_VERSION_ID/$NEW_VERSION_ID/g" $NEW/$each || die "ERROR: String replacemente has failed"
done	

echo "QUESTION: Do you want commit your changes? Temporary files were placed at: $TEMP_DIR"
echo "Press ENTER to proceed to commit or CTRL+C to abort"
read
echo svn ci $TEMP_DIR || die "ERROR: Subversion commit has failed. See directory $TEMP_DIR."
