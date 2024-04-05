#!/bin/bash

# Help Function

help(){

cat <<EOF

██╗      ██████╗  ██████╗
██║     ██╔═══██╗██╔════╝
██║     ██║   ██║██║  ███╗
██║     ██║   ██║██║   ██║
███████╗╚██████╔╝╚██████╔╝
╚══════╝ ╚═════╝  ╚═════╝

██████╗ ██╗   ██╗███╗   ███╗██████╗
██╔══██╗██║   ██║████╗ ████║██╔══██╗
██║  ██║██║   ██║██╔████╔██║██████╔╝
██║  ██║██║   ██║██║╚██╔╝██║██╔═══╝
██████╔╝╚██████╔╝██║ ╚═╝ ██║██║
╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝

Description:

${0} dumps Apache and Nginx's Log Files ->

	access_ssl_log	APACHE		proxy_access_ssl_log	NGINX
	error_log		APACHE		proxy_error_log			NGINX
	access_log		APACHE		proxy_access_log		NGINX

Command Syntax: ${0} [-d|-t|-m|-c|-h]

Usage: ${0} [-d example.com] [-t error_type] {-m mail@example.com} {-c} {-h}

	Options:

	-d --> Specify Domain Name ; e.g. ${0} -d domain.com

	-e --> Specify Error Type [4XX|5XX|3XX] ; e.g. ${0} -d domain.com -t 500

	-m --> Specify Mail Account to send Results; e.g. ${0} -d domain.com -t 400 -m john.doe@domain.com

	-e --> Crontab Lines

	-h --> Help Command

EOF

}

# Log Timestamps Format

d1=$(date +"%Y/%m/%d")

d2=$(date +%d/%b/%Y)

d3=$(date +"%a %b %d")


# Regex Patterns

regex1=".*(processed|gz).*"			# Processed and .GZ Files (LogRotate)

regex2=".*((\s[3,4,5]\d{2}\s)|(err|warn)).*"	# 3XX, 4XX, 5XX HTTP Status Codes

regex3=".*\s[2]\d{2}\s.*"			# 200 HTTP Status Codes

regex4=".*((${d1}\s\d{2}(:\d{2}){2})|(${d2}\s?:?\d{2}(:\d{2}){2})|${d3}\s\d{2}(:\d{2}){2}\.\d+\s2023).*"	# Log Files Timestamps Filter (Current Date)


# Log Files Path

readarray -t webs < <( find /var/www/vhosts/ -maxdepth 1 -type d -regextype posix-extended -regex '.*\.(com|es)$.*' | grep -oiPa '.*/\K.+\..+$') # Web Array Definition

# Log Dump Command

web_log_path=""

# Parameters Check - 1 Parameter Required

if [ $# -eq 0 ]; then

	echo; echo -e "     Parameter Required\n"
	echo -e "     Try -h --> Help Command\n"
	echo -e "     Dominios Disponibles: ${webs[@]}\n"
	exit 1

fi

# Control

ctrl=0

# Flag Options

t_flag=false
t_value=0

d_value=""

m_value=""
m_flag=false

while getopts ":hd:t:m::c" option; do # Script Options and Arguments

	case $option in

		h) help; exit;; # Help Option

		d)	web_log_path="/var/www/vhosts/${OPTARG}/logs/" # Domain Option
			d_value="${OPTARG}"

			for i in "${webs[@]}"; do # For Loop through Array Elements

				if [ "${OPTARG}" = "${i}" ]; then # Check if -d Argument is in Array

					ctrl=1; d_value="${OPTARG}" ;break # Enable Control Variable if -d Arg is in Array

				fi

			done

			if [ "${ctrl}" = 1 ]; then # Create Dump Command if Domain is Correctly Specified

				total_dump=$(find $web_log_path -maxdepth 1 -type f -regextype posix-extended -not -regex "${regex1}" -exec grep -aiP "${regex2}" {} + | grep -aiPv "${regex3}" | grep -aiP "${regex4}")

			else

				echo ""; echo -e "     Invalid Domain Name: ${OPTARG}\n"
				echo -e "     Try: ${webs[@]}\n"

			fi;;

		 t)	t_flag=true; t_value="${OPTARG}" # Error Type Option

			if [ "${ctrl}" = 1 ] && ! test -z $t_value; then # If Control Variable is enabled and -t Option has arg

				if [ $OPTARG = 500 ]; then # Error 500 Dump Log

					dump_500=$(echo "${total_dump}" | grep -aiP '.*\s5\d{2}\s.*'); # echo "${dump_500}

				elif [ $OPTARG = 400 ]; then # Error 400 Dump Log

					dump_400=$(echo "${total_dump}" | grep -aiP '.*\s4\d{2}\s.*' | grep -aiPv '.*((xmlrpc|wp\-login)\.php\s|cache).*'); # echo "${dump_400}

				elif [ $OPTARG = 300 ]; then # Error 300 Dump Log

                                        dump_300=$(echo "${total_dump}" | grep -aiP '.*\s3\d{2}\s.*' | grep -aiPv '.*((xmlrpc|wp\-login)\.php\s|cache).*'); # echo "${dump_300}

				else

					echo; echo -e "     Invalid Argument: -t option --> ${OPTARG}\n"; exit 1

				fi

			elif test -z "${d_value}" && test -z "${t_value}"; then

				echo ""; echo -e "     -d Option not specified\n"; exit 1

			fi;;

		m)	m_flag=true
			regex_mail="^[A-Za-z0-9\-_\.]+@[A-Za-z0-9_\-]+\.[a-zA-Z]+$"
			m_value="${OPTARG}"

			if [[ $m_value =~ $regex_mail ]] && [ $ctrl = 1 ] && ! test -z "${m_value}"; then

				if [ $t_value = 500 ]; then

					echo "${dump_500}" | mail -s "500 Error Log Dump - ${d_value} - $(date +%d/%m/%Y)" "${m_value}"
					echo ""; echo -e "     Mail Sent to ${m_value}\n"

				elif [ $t_value = 400 ]; then

					echo "${dump_400}" | mail -s "400 Error Log Dump - ${d_value} - $(date +%d/%m/%Y)" "${m_value}"
					echo ""; echo -e "     Mail Sent to ${m_value}\n"

				elif [ $t_value = 300 ]; then

                                        echo "${dump_300}" | mail -s "300 Error Log Dump - ${d_value} - $(date +%d/%m/%Y)" "${m_value}"
                                        echo ""; echo -e "     Mail Sent to ${m_value}\n"

				elif ! $t_flag; then

					echo "${total_dump}" | mail -s "Total Error and Warning Log Dump - ${d_value} - $(date +%d/%m/%Y)" "${m_value}"
					echo ""; echo -e "     Mail Sent to ${m_value}\n"
				fi

			else

				echo ""; echo -e "     -m: Invalid Argument --> ${OPTARG}\n"; exit 1

			fi;;

		c)	echo ""; echo -e "     Add To /etc/crontab:\n"
				 echo -e "     500 --> 0 23     * * *	root	bash ${0} -d example.com -t 500 -m john.doe@example.com\n"
				 echo -e "     400 --> 0 23     * * *   root    bash ${0} -d example.com -t 400 -m john.doe@example.com\n"
				 echo -e "     300 --> 0 23     * * *   root    bash ${0} -d example.com -t 300 -m john.doe@example.com\n"
		         	 echo -e "     All Errors  --> 0 23      * * *	root    bash ${0} -d example.com -m john.doe@example.com\n"
			exit 1;;

		\?) echo; echo -e "     Error: Invalid Option --> ${OPTARG}\n"; exit 1;;

		:) echo; echo -e "      -${OPTARG} Option requires Argument\n"; exit 1;;

	esac

done

# Log Dump Summary Variables Definition

total_dump_lines=$(echo "${total_dump}" | wc -l)
total_dump_500_lines=$(echo "${total_dump}" | grep -aiP '.*\s5\d{2}\s.*' | wc -l)
total_dump_400_lines=$(echo "${total_dump}" | grep -aiP '.*\s4\d{2}\s.*' | wc -l)
total_dump_300_lines=$(echo "${total_dump}" | grep -aiP '.*\s3\d{2}\s.*' | wc -l)
td_warn_err_lines=$(echo "${total_dump}" | grep -aiP '.*(warn|err).*' | wc -l)

dump_500_lines=$(echo "${dump_500}" | wc -l) # 500 Dump Total Lines
dump_400_lines=$(echo "${dump_400}" | wc -l) # 400 Dump Total Lines
dump_300_lines=$(echo "${dump_300}" | wc -l) # 300 Dump Total Lines

if [ $ctrl = 1 ] && ! $t_flag && ! $m_flag; then # Total Dump if -t option is not specified

	# Logs Dump Standard Output

	echo "${total_dump}"

	# Logs Dump Summary

	echo; echo; echo -e "     Log Dump Summary:\n"
	echo -e "     Error 5XX Lines Found --> ${total_dump_500_lines}\n"
	echo -e "     Error 4XX Lines Found --> ${total_dump_400_lines}\n\n"
	echo -e "     Error 3XX Lines Found --> ${total_dump_300_lines}\n\n"
	echo -e "     PHP Errors - Warnings Lines Found  --> ${td_warn_err_lines}\n\n"
	echo -e "     Total Lines Found: ${total_dump_lines}\n"


elif [ $ctrl = 1 ] && [ $t_value = 500 ] && ! $m_flag; then

	echo "${dump_500}"

	# Logs Dump Summary

	echo; echo; echo -e "     Log Dump Summary:\n"
        echo -e "     Error 5XX Lines Found --> ${dump_500_lines}\n"

elif [ $ctrl = 1 ] && [ $t_value = 400 ] && ! $m_flag; then

	echo "${dump_400}"

	# Logs Dump Summary

	echo; echo; echo -e "     Log Dump Summary:\n"
        echo -e "     Error 4XX Lines Found --> ${dump_400_lines}\n"

elif [ $ctrl = 1 ] && [ $t_value = 300 ] && ! $m_flag; then

        echo "${dump_300}"

        # Logs Dump Summary

        echo; echo; echo -e "     Log Dump Summary:\n"
        echo -e "     Error 3XX Lines Found --> ${dump_300_lines}\n"

fi
