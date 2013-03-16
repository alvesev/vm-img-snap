#!/bin/bash

#
#  Copyright 2008 Alex Vesev
#
#  This file is part of VIS - VM Img Snap.
#
#  VIS is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  VIS is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with VIS.  If not, see <http://www.gnu.org/licenses/>.
#
##

#  VIS is a tool to assist with a virtual machine snapshot routine
#  operations.
#
##

# bug: spaces in '${libvirt_strg_conf_dir}/*.xml' will bring error

##########################
##  variables declarations

   # routine name to be launched
routine="${1:-help}"
   # array with paths to QEMU storage images
wrk_obj=("${2}") ; wrk_obj="$( sed 's/\/$//g' <<< "${wrk_obj}" )"
   # the binary utility for qemu storage images management
qimg="qemu-img"
   # libvirt directory with storages configurations
libvirt_strg_conf_dir="/etc/libvirt/storage"
   # error state, if not zero, then error was
error_state=0

##  variables declarations
##########################

#########################
##  function declarations
function print_man {
     echo -e "Usage:\n\n $( basename "$0" ) ls|info|list|create|apply|delete [ /directory/name | /image/file/name ]\n\nIf needed it will show avialable snapshots and ask for one of the names.\nThe 'ls' routine will show file list in specified directory or in libvirt storages if no directory specified."
}

function ls_files
{
   ls_dir=${1:-.}
   echo -e "\n\033[1m===>\033[0m In '\033[1m${ls_dir}/\033[0m', there is/are file/files:"
   ls -1 "${ls_dir}"
   ls_files_return_code=$?
   return $ls_files_return_code
}
##  function declarations
#########################


###---###---###---###---###---###---###---###---###

case "${routine}" in
   ""|help|--help|-h|h)
       print_man
       exit $?
   ;;
esac

[ $UID != 0 ] && echo "This script must be run as root." >&2 && exit 1

[ ! -d "${libvirt_strg_conf_dir}" ] && echo "Error [ $0 ]:$LINENO: Not found libvirt directory with storages configurations '${libvirt_strg_conf_dir}'. May you need to create a new storage for a host?" >&2 && exit 1

# find in libvirt configuration files all paths to storages
if [ -z "${wrk_obj[0]}" ] ; then
   i=0
   while read val ; do
      if [ -d "${val}" ] ; then
         wrk_obj[i]=${val}
         ((i++))
      else
         echo "Error [ $0 ]:$LINENO: not found directory '${wrk_obj[$val]}'."
         error_state=1
      fi
   done <<< "$( grep --no-filename '<path>' ${libvirt_strg_conf_dir}/*.xml | sed 's/[ \t]\+<path>//g' | sed 's#</path>$##g' | sed 's/\/$//g' 2>/dev/null )" # strip several templates and trailing symbol '/' if any
fi

case "${routine}" in
   ls)
      # list files in storages directories
      [ -n "${wrk_obj[0]}" ] && \
         for val in $( seq 0 $(( ${#wrk_obj[@]}-1 )) ) ; do
            if ! ls_files "${wrk_obj[$val]}" ; then error_state=1 ; fi
         done
      exit $error_state
   ;;
esac



if [ -e "${wrk_obj}" ] && [ ! -d "${wrk_obj}" ] ; then
   case "${routine}" in
      info)
         "${qimg}" info "${wrk_obj}"
      ;;
      list)
         img_list="$( "${qimg}" snapshot -l "${wrk_obj}" )"
         if [ -z "${img_list}" ] ; then
            echo "There is no snapshots in '${wrk_obj}'."
         else
            echo "Here is the ${img_list}"
         fi
      ;;
      create)
         echo -n "Enter snapshot tag to be created ( tag name format '$( date '+%Y-%m-%d_%H-%M' )' will be not a worst idea): "
         read snapshot_tag
         echo -e "\nTo create snapshot use command\n\n\"${qimg}\" snapshot -c \"${snapshot_tag}\" \"${wrk_obj}\"\n"
      ;;
      apply)
         full_snapshot_list="Here is the $( "${qimg}" snapshot -l "${wrk_obj}" )"
         snapshot_tags_list="$( awk '{print $2}' <<< "${full_snapshot_list}" | tail --lines=+3 )"
         echo -e "List of available snapshots tags:\n${snapshot_tags_list}"
         snapshot_exist="false"
         while [ "${snapshot_exist}" != "true" ] ; do
            echo -n "Please enter snapshot tag to be restored: "
            read snapshot_tag
            while read s_name ; do
               [ "$snapshot_tag" == "${s_name}" ] && snapshot_exist="true"
            done <<< "${snapshot_tags_list}"
            if [ "${snapshot_exist}" != "true" ] ; then
               echo "Not found tag '${snapshot_tag}'."
            fi
         done
         echo -e "To restore snapshot '${snapshot_tag}' use command\n\n\"${qimg}\" snapshot -a \"${snapshot_tag}\" \"${wrk_obj}\"\n"
      ;;
      delete)
         full_snapshot_list="Here is the $( "${qimg}" snapshot -l "${wrk_obj}" )"
         snapshot_tags_list="$( awk '{print $2}' <<< "${full_snapshot_list}" | tail --lines=+3 )"
         echo -e "List of available snapshots tags:\n${snapshot_tags_list}"
         snapshot_exist="false"
         while [ "${snapshot_exist}" != "true" ] ; do
            echo -n "Please enter snapshot tag to be DELETED: "
            read snapshot_tag
            while read s_name ; do
               [ "${snapshot_tag}" == "${s_name}" ] && snapshot_exist="true"
            done <<< "${snapshot_tags_list}"
            if [ "${snapshot_exist}" != "true" ] ; then
               echo "Not found tag '${snapshot_tag}'."
            fi
         done
         echo -e "To DELETE snapshot '${snapshot_tag}' use the command\n\n\"${qimg}\" snapshot -d \"${snapshot_tag}\" \"${wrk_obj}\"\n"
      ;;
      *)
         print_man
         exit $?
      ;;
   esac
else
   echo "Error [ $0 ]:$LINENO: File '${wrk_obj}' not found, or it is directory." && exit 1
fi

exit $?
