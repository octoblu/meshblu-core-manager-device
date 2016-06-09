#!/bin/bash

assert_dependents(){
  local npm_dependents_version="$(npm-dependents --version)"
  if [ "$npm_dependents_version" != "v2.2.0" ]; then
    echo ""
    echo "update-all-dependencies requires @octoblu/npm-dependents == v2.2.0"
    exit 1
  fi
}

clone_repo(){
  local dependent="$1"

  git clone "git@github.com:octoblu/$dependent"
}

find_dependents(){
  npm-dependents --list
}

get_new_version(){
  local name=$(jq -r '.name' package.json)
  local version=$(jq -r '.version' package.json)
  echo "${name}@^${version}"
}

gump_it(){
  local new_version="$1"
  gump --major "Updating to: $new_version"
}

run_tests(){
  npm install \
  && npm test
}

update_dependency(){
  local new_version="$1"

  npm install "$new_version"
}

update_dependent(){
  local new_version="$1"
  local dependent="$2"
  local original_dir="$(pwd)"
  local dependent_dir="${original_dir}/tmp/${dependent}"

  mkdir -p tmp \
  && cd tmp \
  && clone_repo "$dependent" \
  && cd "$dependent_dir" \
  && update_dependency "$new_version" \
  && run_tests \
  && gump_it "$new_version"

  local exit_code=$?

  cd "$original_dir"
  return $exit_code
}

main(){
  assert_dependents
  rm -rf tmp
  local dependents=( $(find_dependents) )
  local new_version="$(get_new_version)"

  for dependent in "${dependents[@]}"; do
    update_dependent "$new_version" "$dependent"
    local exit_code=$?
    if [ "$exit_code" != 0 ]; then
      echo ""
      echo "something bad happened, exiting."
      exit 1
    fi
  done
}
main $@
