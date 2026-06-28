#!/bin/bash
#
# Apache License 2.0
#
# Author: Jan Mutter (info@jayefem.de), 2017-2019
#
# For configuration copy _shelltools to .shelltools and put it to:
# - Your home directory (e.g. ~/.shelltools) or
# - This directory (e.g. /shelltools/.shelltools)
#
# Script is not standalone but called by build.sh and run.sh
# The following variables should be already set from calling script:
# 	- MY_DIR
# 	- MY_EXEC_NAME (values: run | stop | build | clean)
#

MY_LIB_DIR="$MY_DIR"

# Load libraries
source ${MY_LIB_DIR}lib_shelltools.sh

function setup {
	NO_RUN=""
	DRYRUN=""
}

function loadConfiguration {
	if [[ -f "${HOME}/.shelltools" ]]; then
		source "${HOME}/.shelltools"
	elif [[ -f "${MY_DIR}.shelltools" ]]; then
		source ${MY_DIR}.shelltools
	elif [[ -f "${MY_DIR}pcd.config" ]]; then
		# Keep this for downward compatability
		source ${MY_DIR}pcd.config
	fi
}

function initialize {
	if [[ -n "$PEXEC_ALREADY_INITIALIZED" ]];then
		# Only one initialization per session. Start new Bash for new configurations
		return
	fi

	# Load configuration
	loadConfiguration

	if [[ "$PROFILE_SHELL" != "zsh" ]]; then
		# allexport: Automatically exports all variables and functions that you create or modify after giving this command.
		set -a
	fi
		
	configMap="run"_configMap_
	for line in "${runConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "run - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="runAlias"_configMap_
	for line in "${runAliasConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#*\#\#\#}"

		#echo "runAlias - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="stop"_configMap_
	for line in "${stopConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "stop - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="stopAlias"_configMap_
	for line in "${stopAliasConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#*\#\#\#}"

		#echo "stopAlias - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="test"_configMap_
	for line in "${testConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "test - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="testAlias"_configMap_
	for line in "${testAliasConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#*\#\#\#}"

		#echo "testAlias - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="clean"_configMap_
	for line in "${cleanConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		# echo "clean - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="build"_configMap_
	for line in "${buildConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "build - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	export PEXEC_ALREADY_INITIALIZED=true
}

function changeToApplicationDir {
	if [ -n "$PARAM_PROJECT_NAME" ]; then
		source $MY_DIR"pcd.sh" --no-warning $PARAM_PROJECT_NAME

		if [[ "$RETURN_CODE" == "NO_PORJECT_FOUND" ]];then
			PARAM_EXEC_ALIAS=$PARAM_PROJECT_NAME
		fi
	fi

	APPLICATION_DIR="$(basename `pwd`)"
}

function changeConsoleTitle {
	title=$*

	#if [[ "$PROFILE_SHELL" == "zsh" ]]; then
	#	BACKUP_DISABLE_AUTO_TITLE=$DISABLE_AUTO_TITLE
	#	export DISABLE_AUTO_TITLE="true"
	#fi

	chrlen=${#title}
	if [[ "${chrlen}" -gt "45" ]];then
		start=${title:0:20}
		end=${title: -20}
		consoletitle="${start} ... ${end}"
	else
		consoletitle=${title}
	fi
	
	case $TERM in
		xterm*)
			if [ -n "$ZSH_VERSION" ]; then
				print -Pn "\e]0;${APPLICATION_DIR} - ${consoletitle}\a"
			elif [ -n "$BASH_VERSION" ]; then
				printf '\033]0;%s - %s\007' "$APPLICATION_DIR" "$consoletitle"
			fi
			
			;;
	esac


}

#function restoreConsoleTitle {
	#if [[ "$PROFILE_SHELL" == "zsh" ]]; then
	#	export DISABLE_AUTO_TITLE=$BACKUP_DISABLE_AUTO_TITLE
	#fi	
#}

function runCommand {
	runCmd=$*

	echo "Run: ${runCmd}"

	if [[ "$DRYRUN" == "true" ]];then
		echo ""
		echo "== Dry run. Did not execute command. =="
		return
	fi

	#if [[ "${MY_EXEC_NAME}" == "clean" ]];then
	#	userInteractionExitOnNo
	#fi
	
	changeConsoleTitle ${runCmd}

	eval ${runCmd}

	#restoreConsoleTitle
}

function buildDefault {
	#echo "buildDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn clean compile"
	elif [[ -f "build.gradle" ]];then
		runCommand "./gradlew clean compileJava"
	elif [[ -f "package.json" ]];then
		#echo "NPM"
		runCommand "npm pack"
	elif [[ -f "Cargo.toml" ]];then
		#echo "Rust"
		runCommand "cargo build"
	else
		echo "No project found"
	fi
}

function cleanDefault {
	#if [[ -f "pom.xml" ]];then
	#	execCommandStr = "mvn clean"
	#elif [[ -f "build.gradle" ]];then
	#	execCommandStr = "./gradlew clean"
	#elif [[ -f "package.json" ]];then
	#	execCommandStr = "rm -rf node_modules/"
	#else
	#	echo "No command found"
	#	return
	#fi

	echo "No command found"
	return

	runCommand ${execCommandStr}
}

function testDefault {
	#echo "testDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn test"
	elif [[ -f "build.gradle" ]];then
		runCommand "./gradlew test"
	elif [[ -f "Cargo.toml" ]];then
		#echo "Rust"
		runCommand "cargo test"
	else
		echo "No command found"
	fi
}

function runDefault {
	#echo "runDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn spring-boot:run"
	elif [[ -f "build.gradle" ]];then
		runCommand "./gradlew bootRun"
	elif [[ -f "Vagrantfile" ]];then
		runCommand "vagrant up"
	elif [[ -f "package.json" ]];then
		runCommand "npm start"
	elif [[ -f "Cargo.toml" ]];then
		#echo "Rust"
		runCommand "cargo run"
	else
		echo "No command found"
	fi
}

function stopDefault {
	#echo "stopDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn spring-boot:stop"
	elif [[ -f "Vagrantfile" ]];then
		runCommand "vagrant halt"
	elif [[ -f "package.json" ]];then
		runCommand "npm stop"
	else
		echo "No command found"
	fi
}

function execute {
	if [ -z "$APPLICATION_DIR" ]; then
		return
	fi

	if [[ -n "$PARAM_EXEC_ALIAS" ]];then
		execAlias
	else
		execNormal
	fi
}

function execAlias {
	key=$APPLICATION_DIR
	configMapName=${MY_EXEC_NAME}

	key="${key}###${PARAM_EXEC_ALIAS}"
	configMapName="${configMapName}Alias"

	configMap=${configMapName}_configMap_
	projectCmd=$(map_get $configMap $key)

	# echo "configMap: ${configMap} - key: $key - projectCmd: $projectCmd"

	if [[ -z "$projectCmd" ]];then
		echo "No command found. Script aborted."

		return
	fi

	execProjectCmd $projectCmd
}

function execNormal {
	key=$APPLICATION_DIR
	configMapName=${MY_EXEC_NAME}

	configMap=${configMapName}_configMap_
	projectCmd=$(map_get $configMap $key)

	# echo "configMap: ${configMap} - key: $key - projectCmd: $projectCmd"

	execProjectCmd $projectCmd
}

function execProjectCmd {
	projectCmd=$*

	if [ -n "$projectCmd" ]; then
		runCommand $projectCmd
	else
		if [[ "${MY_EXEC_NAME}" == "run" ]];then
			runDefault
		elif [[ "${MY_EXEC_NAME}" == "stop" ]];then
			stopDefault
		elif [[ "${MY_EXEC_NAME}" == "test" ]];then
			testDefault
		elif [[ "${MY_EXEC_NAME}" == "clean" ]];then
			cleanDefault
		else
			buildDefault
		fi
	fi
}

function usage {
	echo ""
	echo "Usage: ${MY_EXEC_NAME} [ -h | --help ] [ --dryrun ] [ <alias> ] [ <projectname> ]"
	echo ""
	echo " -h | --help     : Prints this help."
	echo " --dryrun        : Dry run. Prints the command without executing it."
	echo ""
	echo "This program '${MY_EXEC_NAME}' executes a certain command according to the given <projectname>."
	echo ""
	echo "For configuration copy _shelltools to .shelltools and put it to:"
	echo " - Your home directory (e.g. ~/.shelltools) or"
	echo " - This directory (e.g. /shelltools/.shelltools)"
	echo ""
	echo "See also https://github.com/jayefem/shelltools"
	echo ""

	NO_RUN="true"
}

function parseCommandoLineParameters {
	PARAM_EXEC_ALIAS=""
	PARAM_PROJECT_NAME=""

	while [ "$1" != "" ]; do
		case $1 in
			-h|--help)
				usage;;
			--dryrun)
				DRYRUN=true;;
			--dryRun)
				DRYRUN=true;;
			*)
				break
        		;;
	   esac

	   shift
	done

	if [[ -n "$2" ]];then
		PARAM_EXEC_ALIAS=$1
		PARAM_PROJECT_NAME=$2
	else
		PARAM_PROJECT_NAME=$1
	fi
}

setup

parseCommandoLineParameters $@

if [[ -z "${NO_RUN}" ]]; then
	initialize

	changeToApplicationDir "$1"

	execute
fi

