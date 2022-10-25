#_____________________________________Functions_____________________________________

initialSetup(){
#get environment variables
	source .env
	source ~/.zshrc
	cd ../Katas
}

getRepoName(){
#Repository Name
while [ -z "$repo_name" ]; do
read -p "Enter the repository name: " repo_name
done
}

setupTokens(){
#Snyk and sonarCloud Tokens
checkToken "SONAR_TOKEN" "https://sonarcloud.io/account/security/" "sonar cloud"
checkToken "SNYK_TOKEN" "https://app.snyk.io/account" "snyk"
export TF_VAR_token=$SONAR_TOKEN
}
checkToken (){
# Check for non empty tokens
	token=$1
	while [ -z  "${!token}" ]; do
		open $2
		read -p "Please generate & introduce the token for $3"  ${token}
	done
}

variableFormating(){ 
	repo_name=$(echo $repo_name| tr '[:upper:]' '[:lower:]'| sed 's/[^a-z)]/ /g')
	title=$(echo $repo_name | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')
	repo_name=$(echo $repo_name| sed 's/ /-/g')
	camel_name=$(echo $repo_name| awk -F"-" '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}} 1' OFS="")
	echo "Variables formatted!"
}

checkTemplateAndUsername(){
#Template URL

	while [ -z "$template_url" ]; do
		read -p "Enter the template url (default https://github.ibm.com/Luis-Rolando-Conde-Esnayra/template-tdd-node-js): " template_url
		template_url=${template_url:="https://github.ibm.com/Luis-Rolando-Conde-Esnayra/template-tdd-node-js"}
	done


#Username
	while [ -z "$username" ]; do
		read -p "Enter  github username " username	
	done
}

#Login in github 
githubLogin(){
	gh auth status  --hostname github.ibm.com 
	if [ "$?" == "0" ]; then 
			echo "Logged In" 
	else 
			gh auth login --hostname github.ibm.com
	fi
}

#Repository creation from template
repoCreateClone(){
	gh repo create $repo_name --public --template $template_url && echo "Created complete" 
	while  [ "${returnCode}" != "0" ]; do
		returnCode=$?
		sleep 1;
	done
 	sleep 5
#Repository cloning
	gh repo clone https://github.ibm.com/$username/$repo_name && echo "Cloned complete" 
	while  [ "${returnCode}" != "0" ]; do
		returnCode=$?
		sleep 1;
	done
	
	cd $repo_name
}

# Login in travis and sync up repositories
travisLoginSync(){
	gh_token=$(echo $GITHUB_ACCESS_TOKEN)
	travis login --github-token $gh_token
	travis sync
	echo "Travis logged in"
}


#Removing template references
removeReferences(){
	sed -i '' 's/Luis-Rolando-Conde-Esnayra/'$username'/g' sonar-project.properties
	sed -i '' 's/template-tdd-node-js/'$repo_name'/g' sonar-project.properties
	sed -i '' 's/node-js-template/'$SONAR_IDENTIFIER''$repo_name'/g' sonar-project.properties
	sed -i '' 's/sonarOrg/'$SONAR_ORG'/g' sonar-project.properties
	sed -i '' 's/"name": "nodejs-template",/"name": "'$repo_name'",/g' package.json 
	sed -i '' 's/Dummy/'$camel_name'/g' src/Dummy.js test/Dummy.test.js
	sed -i '' 's/Title/'"$title"'/g' README.md
	sed -i '' 's/dummy/'"$repo_name"'/g' README.md
	sed -i '' 's/Luis-Rolando-Conde-Esnayra/'"$username"'/g' README.md
	sed -i '' 's/Homulilly_Clara_dolls/'$SONAR_IDENTIFIER''$repo_name'/g' project.tf
	mv src/Dummy.js src/$camel_name.js
	mv test/Dummy.test.js test/$camel_name.test.js
	echo "References removed!"

}

#.env creation and adding tokens
manageEnvFile(){
	touch .env
	echo "SONAR_TOKEN="$SONAR_TOKEN >> .env
	echo "SNYK_TOKEN="$SNYK_TOKEN >> .env
	echo "TF_VAR_token="$TF_VAR_token >> .env
	echo "Environment variables Saved!"
}

# Terraform 
runTerraform(){
	terraform init
	terraform apply -var="token=$SONAR_TOKEN" -auto-approve
}

#snyk tests and monitoring
runSnyk(){
	npx snyk auth $SNYK_TOKEN
	if [ "$?" == "0" ]; then 
		echo "Logged In"
		npm run snykrun
		npx snyk monitor
	else 
		echo "Login failed"
	fi
}
#run SonarCloud 
runSonar(){
	npm test 
	npm run sonarrun
	echo "Sonar Running"
	   curl --include \
        --request POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
		-u ${SONAR_TOKEN}: \
		-d "key=sonar.leak.period&value=previous_version&component=${SONAR_IDENTIFIER}${repo_name}" \
        'https://sonarcloud.io/api/settings/set'
		
		  curl --include \
        --request POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
		-u ${SONAR_TOKEN}: \
		-d "key=sonar.leak.period.type&value=previous_version&component=${SONAR_IDENTIFIER}${repo_name}" \
        'https://sonarcloud.io/api/settings/set'

}

# Enable repo in travis
enableTravis(){
    travis enable -r $username/$repo_name 
	echo yes | travis env set SNYK_TOKEN $SNYK_TOKEN -p 
	echo yes | travis env set SONAR_TOKEN $SONAR_TOKEN -p 
	echo "Travis enabled & variables set!"
}

#git commit and push
initialCommit(){
	git pull
	git add . 
	git commit -m "chore: initial commit" && echo "initial commit complete"
	git push origin main && echo "push main complete"
}

#open vscode on proyect folder
openTabs(){ 
	open https://app.snyk.io/
	open https://sonarcloud.io/project/overview?id=$SONAR_IDENTIFIER$repo_name
	open https://travis.ibm.com/$username/$repo_name
	code .
	echo "Repo creation succesful"
}


#__________________________________PROJECT CONFIGURATION________________________________________


initialSetup

getRepoName

variableFormating

checkTemplateAndUsername

setupTokens
#__________________________________GithubSetup________________________________________

githubLogin

repoCreateClone

travisLoginSync

#__________________________________Manage npm and Files________________________________________
removeReferences

#change node version
nvm use 

#Install npm packages
npm install

npm audit fix

manageEnvFile

#__________________________________Manage pipeline________________________________________

runTerraform

runSnyk 

runSonar

enableTravis

#__________________________________Final Steps________________________________________

initialCommit

openTabs

