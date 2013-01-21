#!/bin/sh

GITHUB_USER=user # Your username on github
GITHUB_PASSWORD=''  # Your password on github

GITLAB_PREFIX=from-github    # All repos created on gitlab will be prefixed
GITLAB_USER=user             # Your username on your gitlab instance
GITLAB_HOST=git.example.com  # Your gitlab host WITHOUT SCHEMA
GITLAB_TOKEN=                # Your gitlab token 

TMP=`mktemp -dp .`
cd $TMP


curl -s -u "$GITHUB_USER:$GITHUB_PASSWORD" -i 'https://api.github.com/user/repos' |\
   grep ssh_url > private_repos.txt

while read line
do
	url=`echo $line | sed -r 's|^\s*"(.*)":\s"(.*)",*$|\2|'`
	repo=`echo $url | sed -r 's|^.*/(.*)$|\1|'`
	repo_name=`echo $repo | sed -r 's|^(.*).git$|\1|'`
	curl -s -X POST -H "private-token: $GITLAB_TOKEN" \
		-d " {\"name\" : \"$GITLAB_PREFIX-$repo_name\" } "\
		"https://$GITLAB_HOST/api/v3/projects"
	echo $url
	git clone --bare $url $repo
	cd $repo
	push_url="git@$GITLAB_HOST:$GITLAB_USER/$GITLAB_PREFIX-$repo"
	echo "Pushing to URL: $push_url"
	git push --mirror $push_url
	cd ..
done < private_repos.txt

cd ..

rm -rf $TMP


