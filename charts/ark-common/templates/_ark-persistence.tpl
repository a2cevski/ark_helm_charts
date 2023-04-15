{{- define "arkcase.persistence.getBaseSetting" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail "The 'name' parameter must be the name of the setting to retrieve" -}}
  {{- end -}}

  {{- $result := dict -}}

  {{- $global :=(($ctx.Values.global).persistence | default dict) -}}
  {{- if (hasKey $global $name) -}}
    {{- $result = set $result "global" (get $global $name) -}}
  {{- end -}}

  {{- $local := ($ctx.Values.persistence | default dict) -}}
  {{- if (hasKey $local $name) -}}
    {{- $result = set $result "local" (get $local $name) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.getDefaultSetting" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail "The 'name' parameter must be the name of the setting to retrieve" -}}
  {{- end -}}

  {{- $defaults := (include "arkcase.persistence.getBaseSetting" (set . "name" "default") | fromYaml) -}}

  {{- $result := dict -}}

  {{- $global := ($defaults.global | default dict) -}}
  {{- if (hasKey $global $name) -}}
    {{- $result = set $result "global" (get $global $name) -}}
  {{- end -}}

  {{- $local := ($defaults.local | default dict) -}}
  {{- if (hasKey $local $name) -}}
    {{- $result = set $result "local" (get $local $name) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- /* Check if persistence is enabled, assuming a missing setting defaults to true */ -}}
{{- define "arkcase.persistence.enabled" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $local := (include "arkcase.tools.checkEnabledFlag" (.Values.persistence | default dict)) -}}
  {{- $global := (include "arkcase.tools.checkEnabledFlag" ((.Values.global).persistence | default dict)) -}}

  {{- /* Persistence is only enabled if the local and global flags agree that it should be */ -}}
  {{- if (and $local $global) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /* Get the mode of operation value that should be used for everything */ -}}
{{- define "arkcase.persistence.mode" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $mode := "development" -}}
  {{- if (include "arkcase.persistence.enabled" .) -}}
    {{- $storageClassName := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "storageClassName") | fromYaml) -}}
    {{- $storageClassName = (coalesce $storageClassName.global $storageClassName.local | default "" | lower) -}}

    {{- $modes := (include "arkcase.persistence.getBaseSetting" (dict "ctx" . "name" "mode") | fromYaml) -}}
    {{- if or $modes.global $modes.local -}}
      {{- $mode = (coalesce $modes.global $modes.local | lower) -}}
    {{- else if $storageClassName -}}
      {{- $mode = "prod" -}}
    {{- else -}}
      {{- $mode = "dev" -}}
    {{- end -}}

    {{- if and (ne $mode "dev") (ne $mode "development") (ne $mode "prod") (ne $mode "production") -}}
      {{- fail (printf "Unknown development mode '%s' for persistence (l:%s, g:%s)" $mode $modes.local $modes.global) -}}
    {{- end -}}

    {{- if hasPrefix "dev" $mode -}}
      {{- $mode = "development" -}}
    {{- else -}}
      {{- $mode = "production" -}}
    {{- end -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}

{{- /* Get the hostPathRoot value that should be used for everything */ -}}
{{- define "arkcase.persistence.hostPathRoot" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $hostPathRoot := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "hostPathRoot") | fromYaml) -}}
  {{- coalesce $hostPathRoot.global $hostPathRoot.local "/opt/app" -}}
{{- end -}}

{{- /* Get the storageClassName value that should be used for everything */ -}}
{{- define "arkcase.persistence.storageClassName" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "storageClassName") | fromYaml) -}}
  {{- $storageClassName := "" -}}
  {{- $storageClassSet := false -}}
  {{- if and (not $storageClassSet) (hasKey $values "global") -}}
    {{- $storageClassName = $values.global -}}
    {{- if and $storageClassName (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClassName | lower))) -}}
      {{- fail (printf "The value global.persistence.storageClassName must be a valid storage class name: [%s]" $storageClassName) -}}
    {{- end -}}
    {{- $storageClassSet = true -}}
  {{- end -}}
  {{- if and (not $storageClassSet) (hasKey $values "local") -}}
    {{- $storageClassName = $values.local -}}
    {{- if and $storageClassName (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClassName | lower))) -}}
      {{- fail (printf "The value persistence.storageClassName must be a valid storage class name: [%s]" $storageClassName) -}}
    {{- end -}}
    {{- $storageClassSet = true -}}
  {{- end -}}
  {{- /* Only output a value if one is set */ -}}
  {{- if $storageClassName -}}
    {{- $storageClassName -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.persistentVolumeReclaimPolicy" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "persistentVolumeReclaimPolicy") | fromYaml) -}}
  {{- $policy := "" -}}
  {{- if and (not $policy) (hasKey $values "global") -}}
    {{- $policy = $values.global -}}
    {{- if and $policy (not (regexMatch "^(retain|recycle|delete)$" ($policy | lower))) -}}
      {{- fail (printf "The value global.persistence.persistentVolumeReclaimPolicy must be a valid persistent volume reclaim policy (Retain/Recycle/Delete): [%s]" $policy) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $policy) (hasKey $values "local") -}}
    {{- $policy = $values.local -}}
    {{- if and $policy (not (regexMatch "^(retain|recycle|delete)$" ($policy | lower))) -}}
      {{- fail (printf "The value persistence.persistentVolumeReclaimPolicy must be a valid persistent volume reclaim policy (Retain/Recycle/Delete): [%s]" $policy) -}}
    {{- end -}}
  {{- end -}}
  {{- if $policy -}}
    {{- $policy | lower | title -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.accessModes" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "accessModes") | fromYaml) -}}
  {{- $modes := dict -}}
  {{- if and (not $modes) (hasKey $values "global") -}}
    {{- $accessModes = $values.global -}}
    {{- $str := "" -}}
    {{- if kindIs "slice" $accessModes -}}
      {{- $str = join "," $accessModes -}}
    {{- else -}}
      {{- $str := ($accessModes | toString) -}}
    {{- end -}}
    {{- $modes = (include "arkcase.persistence.buildVolume.parseAccessModes" $str) -}}
    {{- if $modes.errors -}}
      {{- fail (printf "Invalid access modes found in the value global.persistence.accessModes: %s" $modes.errors) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $modes) (hasKey $values "local") -}}
    {{- $accessModes = $values.local -}}
    {{- $str := "" -}}
    {{- if kindIs "slice" $accessModes -}}
      {{- $str = join "," $accessModes -}}
    {{- else -}}
      {{- $str := ($accessModes | toString) -}}
    {{- end -}}
    {{- $modes = (include "arkcase.persistence.buildVolume.parseAccessModes" $str) -}}
    {{- if $modes.errors -}}
      {{- fail (printf "Invalid access modes found in the value persistence.accessModes: %s" $modes.errors) -}}
    {{- end -}}
  {{- end -}}
  {{- if $modes.modes -}}
    {{- $modes.modes | compact | join "," -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.capacity" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "capacity") | fromYaml) -}}
  {{- $capacity := "" -}}
  {{- if and (not $capacity) (hasKey $values "global") -}}
    {{- $capacity = (include "arkcase.persistence.buildVolume.parseStorageSize" $values.global | fromYaml) -}}
    {{- if not $capacity -}}
      {{- fail (printf "The value global.persistence.capacity must be a valid persistent volume capacity: [%s]" $values.global) -}}
    {{- end -}}
    {{- $capacity = $values.global -}}
  {{- end -}}
  {{- if and (not $capacity) (hasKey $values "local") -}}
    {{- $capacity = (include "arkcase.persistence.buildVolume.parseStorageSize" $values.local | fromYaml) -}}
    {{- if not $capacity -}}
      {{- fail (printf "The value persistence.capacity must be a valid persistent volume capacity: [%s]" $values.local) -}}
    {{- end -}}
    {{- $capacity = $values.local -}}
  {{- end -}}
  {{- if $capacity -}}
    {{- $capacity -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.volumeMode" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "volumeMode") | fromYaml) -}}
  {{- $volumeMode := "" -}}
  {{- if and (not $volumeMode) (hasKey $values "global") -}}
    {{- $volumeMode = (include "arkcase.persistence.buildVolume.parseVolumeMode" $values.global) -}}
    {{- if not $volumeMode -}}
      {{- fail (printf "The value global.persistence.volumeMode must be a valid persistent volume mode: [%s]" $values.global) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $volumeMode) (hasKey $values "local") -}}
    {{- $volumeMode = (include "arkcase.persistence.buildVolume.parseVolumeMode" $values.local) -}}
    {{- if not $volumeMode -}}
      {{- fail (printf "The value persistence.volumeMode must be a valid persistent volume volume mode: [%s]" $values.local) -}}
    {{- end -}}
  {{- end -}}
  {{- if $volumeMode -}}
    {{- $volumeMode -}}
  {{- end -}}
{{- end -}}

{{- /* Get or define the shared persistence settings for this chart */ -}}
{{- define "arkcase.persistence.settings" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "PersistenceSettings" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey . $cacheKey) -}}
    {{- $masterCache = get . $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set . $cacheKey $masterCache -}}

  {{- /* We specifically don't use arkcase.fullname here b/c we don't care about part names for this */ -}}
  {{- $chartName := (include "common.fullname" .) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $enabled := (eq "true" (include "arkcase.persistence.enabled" . | trim | lower)) -}}
    {{- $hostPathRoot := (include "arkcase.persistence.hostPathRoot" .) -}}
    {{- $storageClassName := (include "arkcase.persistence.storageClassName" .) -}}
    {{- $persistentVolumeReclaimPolicy := (include "arkcase.persistence.persistentVolumeReclaimPolicy" .) -}}
    {{- if not $persistentVolumeReclaimPolicy -}}
      {{- $persistentVolumeReclaimPolicy = "Retain" -}}
    {{- end -}}
    {{- $accessModes := (include "arkcase.persistence.accessModes" .) -}}
    {{- if $accessModes -}}
      {{- $accessModes = splitList "," $accessModes | compact -}}
    {{- end -}}
    {{- if not $accessModes -}}
      {{- /* If no access modes are given by default, use ReadWriteOnce */ -}}
      {{- $accessModes = list "ReadWriteOnce" -}}
    {{- end -}}
    {{- $capacity := (include "arkcase.persistence.capacity" .) -}}
    {{- if not $capacity -}}
      {{- $capacity = "1Gi" -}}
    {{- end -}}
    {{- $volumeMode := (include "arkcase.persistence.volumeMode" .) -}}
    {{- if not $volumeMode -}}
      {{- $volumeMode = "Filesystem" -}}
    {{- end -}}

    {{- $mode := (include "arkcase.persistence.mode" .) -}}
    {{-
      $obj := dict 
        "enabled" $enabled
        "hostPathRoot" $hostPathRoot
        "capacity" $capacity
        "storageClassName" $storageClassName
        "persistentVolumeReclaimPolicy" $persistentVolumeReclaimPolicy
        "accessModes" $accessModes
        "volumeMode" $volumeMode
        "mode" $mode
    -}}
    {{- $masterCache = set $masterCache $chartName $obj -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.sanitizeAccessMode" -}}
  {{- $M := (. | upper) -}}
  {{- if or (eq "RWO" $M) (eq "RW" $M) (eq "READWRITEONCE" $M) -}}
    {{- "ReadWriteOnce" -}}
  {{- else if or (eq "RWM" $M) (eq "RW+" $M) (eq "READWRITEMANY" $M) -}}
    {{- "ReadWriteMany" -}}
  {{- else if or (eq "ROM" $M) (eq "RO" $M) (eq "RO+" $M) (eq "READONLYMANY" $M) -}}
    {{- "ReadOnlyMany" -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseAccessModes" -}}
  {{- $modes := list -}}
  {{- $errors := dict -}}
  {{- $modeMap := dict -}}
  {{- range $m := splitList "," . -}}
    {{- $M := (include "arkcase.persistence.buildVolume.sanitizeAccessMode" (trim $m)) -}}
    {{- if $M -}}
      {{- if not (hasKey $modeMap $M) -}}
        {{- $modes = append $modes $M -}}
        {{- $modeMap = set $modeMap $M $M -}}
      {{- end -}}
    {{- else if $m -}}
      {{- $errors = set $errors $m $m -}}
    {{- end -}}
  {{- end -}}
  {{- dict "modes" $modes "errors" (keys $errors | sortAlpha) | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseStorageSize" -}}
  {{- $min := "" -}}
  {{- $max := "" -}}
  {{- $data := (. | upper) -}}
  {{- $result := dict -}}
  {{- if regexMatch "^[1-9][0-9]*[EPTGMK]I?(-[1-9][0-9]*[EPTGMK]I?)?$" $data -}}
    {{- $parts := split "-" $data -}}
    {{- $min = $parts._0 | replace "I" "i" | replace "K" "k" -}}
    {{- $max = $parts._1 | replace "I" "i" | replace "K" "k" -}}
    {{- $result = dict "min" $min "max" $max -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeMode" -}}
  {{- $mode := (. | toString | lower) -}}
  {{- if or (eq "filesystem" $mode) (eq "block" $mode) -}}
    {{- title $mode -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.path" -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- /* Must be a path ... only valid in development mode */ -}}
  {{- if isAbs $data -}}
    {{- $data = (include "arkcase.tools.normalizePath" $data) -}}
  {{- else -}}
    {{- $data = (include "arkcase.tools.normalizePath" $data) -}}
    {{- if not $data -}}
      {{- fail (printf "The given relative path [%s] for volume '%s' overflows containment (too many '..' components)" .data $volumeName) -}}
    {{- end -}}
  {{- end -}}
  {{- dict "render" (dict "volume" true "claim" true "mode" "hostPath") "hostPath" $data | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.pv" -}}
  {{- /* pv://[${storageClassName}]/${capacity}#${accessModes} */ -}}
  {{- /* /an/absolute/path */ -}}
  {{- /* some/relative/path */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $volume := dict -}}
  {{- if hasPrefix "pv://" ($data | lower) -}}
    {{- /* pv://[${storageClassName}]/${capacity}#${accessModes} */ -}}
    {{- $pv := urlParse $data -}}
    {{- /* Perform QC: may have a storageClassName, must have a capacity and accessModes */ -}}
    {{- $storageClassName := $pv.host | default "" -}}
    {{- if and $storageClassName (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClassName | lower))) -}}
      {{- fail (printf "Invalid storage class in pv:// URL for volume '%s': [%s]" $volumeName $storageClassName) -}}
    {{- end -}}
    {{- $cap := $pv.path | default "" -}}
    {{- $mode := $pv.fragment | default "" -}}
    {{- if or (not $cap) (not $mode) -}}
      {{- fail (printf "The pv:// volume declaration for '%s' must be of the form: pv://[${storageClassName}]/${capacity}#${accessModes} where only the ${storageClassName} portion is optional: [%s]" $volumeName $data) -}}
    {{- end -}}
    {{- $mode = (include "arkcase.persistence.buildVolume.parseAccessModes" $mode | fromYaml) -}}
    {{- if $mode.errors -}}
      {{- fail (printf "Invalid access modes %s given for volume spec '%s': [%s]" $mode.errors $volumeName $data) -}}
    {{- end -}}
    {{- $cap = (clean $cap | trimPrefix "/") -}}
    {{- $capacity := (include "arkcase.persistence.buildVolume.parseStorageSize" $cap | fromYaml) -}}
    {{- if or (not $capacity) $capacity.max -}}
      {{- fail (printf "Invalid capacity specification '%s' for volume '%s': [%s]" $cap $volumeName $data) -}}
    {{- end -}}
    {{- $volume = dict "render" (dict "volume" true "claim" true "mode" "volume") "storageClassName" $storageClassName "capacity" $capacity.min "accessModes" $mode.modes -}}
  {{- else -}}
    {{- /* Punt this to a pvc's vol:// parse */ -}}
    {{- if not (hasPrefix "vol://" ($data | lower)) -}}
      {{- $data = (printf "vol://%s" $data) -}}
    {{- end -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" (dict "data" $data "volumeName" $volumeName) | fromYaml) -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.pvc" -}}
  {{- /* vol://${volumeName}#${accessModes} */ -}}
  {{- /* pvc://[${storageClassName}]/${minSize}[-${maxSize}][#${accessModes}] */ -}}
  {{- /* pvc:${existingPvcName} */ -}}
  {{- /* ${existingPvcName} */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}

  {{- $volume := dict -}}
  {{- if or (hasPrefix "vol://" ($data | lower)) (hasPrefix "pvc:" ($data | lower)) -}}
    {{- /* vol://${volumeName}#${accessModes} */ -}}
    {{- /* pvc://[${storageClassName}]/${minSize}[-${maxSize}][#${accessModes}] */ -}}
    {{- /* pvc:${existingPvcName} */ -}}
    {{- $pvc := urlParse $data -}}
    {{- if or $pvc.query $pvc.userinfo -}}
      {{- fail (printf "Malformed URI for volume '%s': [%s] - may not have userInfo or query data" $volumeName $data) -}}
    {{- end -}}

    {{- $mode := dict -}}
    {{- if $pvc.fragment -}}
      {{- $mode = (include "arkcase.persistence.buildVolume.parseAccessModes" $pvc.fragment | fromYaml) -}}
      {{- if $mode.errors -}}
        {{- fail (printf "Invalid access modes %s given for volume spec '%s': [%s]" $mode.errors $volumeName $data) -}}
      {{- end -}}
    {{- end -}}

    {{- if and $pvc.host (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($pvc.host | lower))) -}}
      {{- fail (printf "Volume '%s' has an invalid first component '%s': [%s]" $volumeName $pvc.host $data) -}}
    {{- end -}}
    {{- if and $pvc.opaque (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($pvc.opaque | lower))) -}}
      {{- fail (printf "Volume '%s' has an invalid first component '%s': [%s]" $volumeName $pvc.opaque $data) -}}
    {{- end -}}

    {{- if eq "vol" ($pvc.scheme | lower) -}}
      {{- /* vol://${volumeName}[#${accessModes}] */ -}}
      {{- if not $pvc.host -}}
        {{- fail (printf "Must provide the name of the volume to connect the PVC to for volume '%s': [%s]" $volumeName $data) -}}
      {{- end -}}
      {{- $volume = dict "render" (dict "volume" false "claim" true "mode" "claim") "volumeName" $pvc.host "accessModes" $mode.modes -}}
    {{- else if eq "pvc" ($pvc.scheme | lower) -}}
      {{- if hasPrefix "pvc://" ($data | lower) -}}
        {{- /* pvc://[${storageClassName}]/${minSize}[-${maxSize}][#${accessModes}] */ -}}
        {{- $limitsRequests := (clean $pvc.path) -}}
        {{- if eq "." $limitsRequests -}}
          {{- fail (printf "No limits-requests specification given for volume '%s': [%s]" $volumeName $data) -}}
        {{- end -}}
        {{- $limitsRequests = ($limitsRequests | trimPrefix "/") -}}
        {{- $size := (include "arkcase.persistence.buildVolume.parseStorageSize" $limitsRequests | fromYaml) -}}
        {{- if not $size -}}
          {{- fail (printf "Invalid limits-requests specification '%s' for volume '%s': [%s]" $limitsRequests $volumeName $data) -}}
        {{- end -}}
        {{- $resources := dict "requests" (dict "storage" $size.min) -}}
        {{- if $size.max -}}
          {{- $resources = set $resources "limits" (dict "storage" $size.max) -}}
        {{- end -}}
        {{- $volume = dict "render" (dict "volume" false "claim" true "mode" "claim") "storageClassName" $pvc.host "accessModes" $mode.modes "resources" $resources -}}
      {{- else -}}
        {{- /* pvc:${existingPvcName} */ -}}
        {{- if not $pvc.opaque -}}
          {{- fail (printf "Must provide the name of the existing PVC to connect to for volume '%s': [%s]" $volumeName $data) -}}
        {{- end -}}
        {{- $volume = dict "render" (dict "volume" false "claim" false "mode" "claim") "claimName" $pvc.opaque -}}
      {{- end -}}
    {{- end -}}
  {{- else if $data -}}
    {{- /* ${existingPvcName} */ -}}
    {{- if not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($data | lower)) -}}
      {{- fail (printf "The PVC name '%s' for volume '%s' is not valid" $data $volumeName) -}}
    {{- end -}}
    {{- $volume = dict "render" (dict "volume" false "claim" false "mode" "claim") "claimName" $data -}}
  {{- else -}}
    {{- fail (printf "The PVC string for volume '%s' cannot be empty" $volumeName) -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString" -}}
  {{- /* Must be a pv:// or a path ... the empty string renders a default volume */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $volume := dict -}}
  {{- if $data -}}
    {{- if or (hasPrefix "pvc:" ($data | lower)) (hasPrefix "vol://" ($data | lower)) -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" . | fromYaml) -}}
    {{- else if (hasPrefix "pv:" ($data | lower)) -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pv" . | fromYaml) -}}
    {{- else -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" . | fromYaml) -}}
    {{- end -}}
  {{- else -}}
    {{- $volume = (dict "render" (dict "volume" true "claim" true "mode" "hostPath")) -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.render" -}}
  {{- $volumeName := .volumeName -}}
  {{- $data := .data -}}
  {{- $mustRender := .mustRender -}}
  {{- $volume := dict -}}
  {{- if kindIs "string" $data -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString" (dict "data" $data "volumeName" $volumeName) | fromYaml) -}}
  {{- else if kindIs "map" $data -}}
    {{- /* May be a map that has "path", "claim", or "volume" ... but only one! */ -}}
    {{- $data = pick $data "path" "claim" "volume" -}}
    {{- if gt (len (keys $data)) 1 -}}
      {{- fail (printf "The volume declaration for %s may only have one of the keys 'path', 'claim', or 'volume': %s" $volumeName (keys $data)) -}}
    {{- end -}}
    {{- if $data.claim -}}
      {{- if kindIs "string" $data.claim -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" (dict "data" $data.claim "volumeName" $volumeName) | fromYaml) -}}
      {{- else if kindIs "map" $data.claim -}}
        {{- $volume = (dict "render" (dict "volume" false "claim" true) "spec" $data.claim) -}}
      {{- else -}}
        {{- fail (printf "The 'claim' value for the volume '%s' must be either a dict or a string (%s)" $volumeName (kindOf $data.claim)) -}}
      {{- end -}}
      {{- $volume = set $volume "render" (set $volume.render "mode" "claim") -}}
    {{- else if $data.volume -}}
      {{- if kindIs "string" $data.volume -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pv" (dict "data" $data.volume "volumeName" $volumeName) | fromYaml) -}}
      {{- else if kindIs "map" $data.volume -}}
        {{- /* The map is a volume spec, so use it */ -}}
        {{- $volume = (dict "render" (dict "volume" true "claim" true) "spec" $data.volume) -}}
      {{- else -}}
        {{- fail (printf "The 'volume' value for the volume '%s' must be either a dict or a string (%s)" $volumeName (kindOf $data.volume)) -}}
      {{- end -}}
      {{- $volume = set $volume "render" (set $volume.render "mode" "volume") -}}
    {{- else -}}
      {{- if $data.path -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" (dict "data" $data.path "volumeName" $volumeName) | fromYaml) -}}
      {{- else -}}
        {{- $volume = (dict "render" (dict "volume" true "claim" true "mode" "hostPath")) -}}
      {{- end -}}
    {{- end -}}
  {{- else if (kindIs "invalid" $data) -}}
    {{- $volume = (dict "render" (dict "volume" true "claim" true "mode" "hostPath")) -}}
  {{- else -}}
    {{- fail (printf "The volume declaration for %s must be either a string or a map (%s)" $volumeName (kindOf $data)) -}}
  {{- end -}}
  {{- set $volume "render" (merge $volume.render (dict "name" $volumeName "mustRender" $mustRender)) | toYaml -}}
{{- end -}}

{{- /*
Parse a volume declaration and return a map that contains the following (possible) keys:
  claim: the PVC that must be rendered, or the name of the PVC that must be used
  volume: the PV that must be rendered
*/ -}}
{{- define "arkcase.persistence.buildVolume.cached" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- if not (hasKey . "name") -}}
    {{- fail "Must provide the 'name' parameter for the volume to be built" -}}
  {{- end -}}
  {{- /* The volume's name will be of the form "[${part}-]$name" ($part is optional) */ -}}
  {{- $name := .name -}}
  {{- $globalName := (printf "%s-%s" $ctx.Chart.Name $name) -}}
  {{- $volumeName := (printf "%s-%s" $ctx.Release.Name $globalName) -}}
  {{- $persistence := ($ctx.Values.persistence | default dict) -}}
  {{- $persistenceVolumes := ($persistence.volumes | default dict) -}}

  {{- $globalPersistence := (($ctx.Values.global).persistence | default dict) -}}
  {{- $globalPersistenceVolumes := ($globalPersistence.volumes | default dict) -}}

  {{- $enabled := (not (empty (include "arkcase.persistence.enabled" $ctx))) -}}
  {{- $mustRender := $enabled -}}

  {{- $data := dict -}}
  {{- if hasKey $persistenceVolumes $name -}}
    {{- $data = get $persistenceVolumes $name -}}
    {{- $mustRender = true -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if hasKey $globalPersistenceVolumes $ctx.Chart.Name -}}
    {{- $globalVolumes := get $globalPersistenceVolumes $ctx.Chart.Name -}}
    {{- if and $globalVolumes (kindIs "map" $globalVolumes) (hasKey $globalVolumes $name) -}}
      {{- $result = (include "arkcase.persistence.buildVolume.render" (dict "volumeName" $volumeName "data" (get $globalVolumes $name) "mustRender" true) | fromYaml) -}}
    {{- end -}}
  {{- end -}}

  {{- /* If we didn't get an override from the global data, we use the local data */ -}}
  {{- if not $result -}}
    {{- $result = (include "arkcase.persistence.buildVolume.render" (dict "volumeName" $volumeName "data" $data "mustRender" $mustRender) | fromYaml) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := .name -}}
  {{- if not $name -}}
    {{- fail "The volume name may not be empty" -}}
  {{- end -}}

  {{- $partname := (include "arkcase.part.name" $ctx) -}}
  {{- if $partname -}}
    {{- $name = (printf "%s-%s" $partname $name) -}}
  {{- end -}}

  {{- $cacheKey := "PersistenceVolumes" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $volumeName := (printf "%s-%s" (include "arkcase.fullname" .) $name) -}}
  {{- if not (hasKey $masterCache $volumeName) -}}
    {{- $obj := (include "arkcase.persistence.buildVolume.cached" (set . "name" $name) | fromYaml) -}}
    {{- $masterCache = set $masterCache $volumeName $obj -}}
  {{- end -}}
  {{- get $masterCache $volumeName | toYaml -}}
{{- end -}}

{{- /* Verify that the persistence configuration is good */ -}}
{{- define "arkcase.persistence.validateVolumeConfig" -}}
  {{- $name := .name -}}
  {{- with .vol -}}
    {{- $hasClaimSpec := false -}}
    {{- $hasClaimName := false -}}
    {{- $hasVolumeSpec := false -}}
    {{- if (.claim) -}}
      {{- if .claim.spec -}}
        {{- $hasClaimSpec = (lt 0 (len (.claim).spec)) -}}
      {{- end -}}
      {{- if .claim.name -}}
        {{- $hasClaimName = true -}}
      {{- end -}}
      {{- if and $hasClaimName $hasClaimSpec -}}
         {{- $message := printf "The persistence definition for [%s] has both claim.name and claim.spec, choose only one" $name -}}
         {{- fail $message -}}
      {{- end -}}
    {{- end -}}
    {{- if (.spec) -}}
      {{- $hasVolumeSpec = (lt 0 (len (.spec))) -}}
    {{- end -}}
    {{- if and (or $hasClaimSpec $hasClaimName) $hasVolumeSpec -}}
       {{- $message := printf "The persistence definition for [%s] has both a claim definition and volume specifictions, choose only one" $name -}}
       {{- fail $message -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
Render a volumes: entry for a given volume, as per the persistence model
*/ -}}
{{- define "arkcase.persistence.volume" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $volumeName := .name -}}
  {{- $volume := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
  {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
  {{- /* We render the volume inline only if it's a hostPath volume, or if persistence is off */ -}}
  {{- if or (not $settings.enabled) ($volume.claimName) (and (eq $settings.mode "development") (eq $volume.render.mode "hostPath")) -}}
    {{- $storageClassName := $settings.storageClassName -}}
    {{- $localPath := "" -}}
    {{- $claimName := $volume.claimName -}}
    {{- if and $settings.enabled (not $volume.claimName) -}}
      {{- $volumeData := omit $volume "render" -}}
      {{- if or (not $volumeData) (hasKey $volumeData "hostPath") -}}
        {{- $localPath = ($volumeData.hostPath | default "") -}}
        {{- if or (not $storageClassName) (hasKey $volumeData "hostPath") -}}
          {{- /* This is a local filesystem spec ... should be in development mode! */ -}}
          {{- if ne $settings.mode "development" -}}
            {{- fail (printf "Local paths are only supported in development mode (volume [%s] for chart %s)" $volumeName $ctx.Chart.Name) -}}
          {{- end -}}
          {{- $storageClassName = "manual" }}
          {{- if not $localPath -}}
            {{- $partname := (include "arkcase.part.name" $ctx) -}}
            {{- if $partname -}}
              {{- $volumeName = (printf "%s-%s" $partname $volumeName) -}}
            {{- end -}}
            {{- $localPath = (printf "%s/%s" (include "arkcase.subsystem.name" $ctx) $volumeName) -}}
          {{- end -}}
          {{- if not (isAbs $localPath) -}}
            {{- $localPath = (printf "%s/%s/%s/%s" $settings.hostPathRoot $ctx.Release.Namespace $ctx.Release.Name $localPath) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
- name: {{ $volumeName | quote }}
    {{- if $localPath }}
  hostPath:
    path: {{ $localPath | quote }}
    type: DirectoryOrCreate
    {{- else if $claimName }}
  persistentVolumeClaim:
    claimName: {{ $claimName | quote }}
    {{- else }}
  emptyDir: {}
    {{- end }}
  {{- end }}
{{- end -}}

{{- /*
Render the PersistentVolume and PersistentVolumeClaim objects for a given volume, per configurations
*/ -}}
{{- define "arkcase.persistence.volumeClaimTemplate" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context" -}}
  {{- end -}}

  {{- $volumeName := .name -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'name' of the volume objects to declare" -}}
  {{- end -}}

  {{- $volumeData := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
  {{- $render := (get $volumeData "render") -}}
  {{- if $render.mustRender -}}
    {{- $partname := (include "arkcase.part.name" $ctx) -}}
    {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
    {{- $volumeData = omit $volumeData "render" -}}

    {{- $hostPathRoot := $settings.hostPathRoot -}}
    {{- $objectName := $render.name -}}
    {{- $volumeObjectName := (printf "%s-%s" $ctx.Release.Namespace $objectName) -}}

    {{- $accessModes := $settings.accessModes -}}
    {{- $capacity := $settings.capacity -}}
    {{- $storageClassName := $settings.storageClassName -}}
    {{- $volumeMode := $settings.volumeMode -}}

    {{- $renderVolume := $render.volume -}}
    {{- if $renderVolume -}}
      {{- if eq $settings.mode "production" -}}
        {{- /* If it's a hostPath volume, avoid rendering the PV object, and only render a PVC with default settings */ -}}
        {{- $renderVolume = (ne $render.mode "hostPath") -}}
      {{- else -}}
        {{- /* In development mode, we only render a volume for hostPath volumes if we have */ -}}
        {{- /* an explicit path set, or we don't have a default storage class set */ -}}
        {{- $renderVolume = (or (hasKey $volumeData "hostPath") (not $storageClassName)) -}}
      {{- end -}}
    {{- end -}}
    {{- if $render.claim -}}
- metadata:
    name: {{ $objectName | quote }}
    labels:
      arkcase/persistentVolumeClaim: {{ $objectName | quote }}
  spec:
      {{- if hasKey $volumeData "spec" }}
        {{- /* We were given a claim declaration, so quote it */ -}}
        {{- $claimSpec := $volumeData.spec -}}
        {{- if $claimSpec.accessModes -}}
          {{- $accessModes = $claimSpec.accessModes -}}
        {{- end -}}
        {{- if ($claimSpec.capacity).storage -}}
          {{- $capacity = $claimSpec.capacity.storage -}}
        {{- end -}}
        {{- if $claimSpec.storageClassName -}}
          {{- $storageClassName = $claimSpec.storageClassName -}}
        {{- end -}}
        {{- toYaml $claimSpec | nindent 2 -}}
      {{- else if $renderVolume }}
    volumeName: {{ $volumeObjectName | quote }}
    selector:
      matchLabels:
        arkcase/persistentVolume: {{ $volumeObjectName | quote }}
        {{- if $storageClassName }}
    storageClassName: {{ $storageClassName | quote }}
        {{- end }}
    accessModes: {{- toYaml $accessModes | nindent 4 }}
    resources:
      requests:
        storage: {{ $capacity | quote }}
      {{- else -}}
        {{- /* This is the product of a pvc:// URI, so do the thing! */ -}}
        {{- if $volumeData.accessModes -}}
          {{- $accessModes = $volumeData.accessModes -}}
        {{- end -}}
        {{- if $volumeData.resources -}}
          {{- $capacity = $volumeData.resources -}}
        {{- else -}}
          {{- $capacity = dict "requests" (dict "storage" $capacity) -}}
        {{- end -}}
        {{- if $volumeData.storageClassName -}}
          {{- $storageClassName = $volumeData.storageClassName -}}
        {{- end }}
        {{- if $volumeData.volumeName }}
    volumeName: {{ $volumeData.volumeName | quote }}
          {{- $storageClassName = "" -}}
        {{- end }}
    accessModes: {{- toYaml $accessModes | nindent 4 }}
    resources: {{- toYaml $capacity | nindent 4 }}
        {{- if $storageClassName }}
    storageClassName: {{ $storageClassName | quote }}
        {{- end }}
    volumeMode: {{ $volumeMode | quote }}
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
Render the PersistentVolume and PersistentVolumeClaim objects for a given volume, per configurations
*/ -}}
{{- define "arkcase.persistence.declareObjects" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context" -}}
  {{- end -}}

  {{- $volumeName := .name -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'name' of the volume objects to declare" -}}
  {{- end -}}

  {{- $volumeData := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
  {{- $render := (get $volumeData "render") -}}
  {{- if $render.mustRender -}}
    {{- $partname := (include "arkcase.part.name" $ctx) -}}
    {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
    {{- $volumeData = omit $volumeData "render" -}}

    {{- $objectName := $render.name -}}
    {{- $volumeObjectName := (printf "%s-%s" $ctx.Release.Namespace $objectName) -}}

    {{- $accessModes := $settings.accessModes -}}
    {{- $capacity := $settings.capacity -}}
    {{- $storageClassName := $settings.storageClassName -}}
    {{- $volumeMode := $settings.volumeMode -}}

    {{- if and $render.volume (ne $render.mode "hostPath") -}}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ $volumeObjectName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
      {{- with $ctx.Values.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $volumeData.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
    arkcase/persistentVolume: {{ $volumeObjectName | quote }}
  annotations:
      {{- with $ctx.Values.annotations  }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $volumeData.annotations  }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
spec:
      {{- if hasKey $volumeData "spec" }}
        {{- /* We were given a volume declaration, so quote it */ -}}
        {{- $volumeSpec := $volumeData.spec -}}
        {{- if $volumeSpec.storageClassName -}}
          {{- $storageClassName = $volumeSpec.storageClassName -}}
        {{- end -}}
        {{- if ($volumeSpec.capacity).storage -}}
          {{- $capacity = $volumeSpec.capacity.storage -}}
        {{- end -}}
        {{- if $volumeSpec.accessModes -}}
          {{- $accessModes = $volumeSpec.accessModes -}}
        {{- end -}}
        {{- toYaml $volumeSpec | nindent 2 -}}
      {{- else -}}
        {{- $localPath := "" -}}
        {{- if or (not $volumeData) (hasKey $volumeData "hostPath") -}}
          {{- $localPath = ($volumeData.hostPath | default "") -}}
          {{- if or (not $storageClassName) (hasKey $volumeData "hostPath") -}}
            {{- /* This is a local filesystem spec ... should be in development mode! */ -}}
            {{- if ne $settings.mode "development" -}}
              {{- fail (printf "Local paths are only supported in development mode (volume [%s] for chart %s)" $volumeName $ctx.Chart.Name) -}}
            {{- end -}}
            {{- $storageClassName = "manual" }}
            {{- if not $localPath -}}
              {{- if $partname -}}
                {{- $volumeName = (printf "%s-%s" $partname $volumeName) -}}
              {{- end -}}
              {{- $localPath = (printf "%s/%s" (include "arkcase.subsystem.name" $ctx) $volumeName) -}}
            {{- end -}}
            {{- if not (isAbs $localPath) -}}
              {{- $localPath = (printf "%s/%s/%s/%s" $settings.hostPathRoot $ctx.Release.Namespace $ctx.Release.Name $localPath) -}}
            {{- end -}}
          {{- end -}}
        {{- else -}}
          {{- if $volumeData.storageClassName -}}
            {{- $storageClassName = $volumeData.storageClassName -}}
          {{- end -}}
          {{- if $volumeData.capacity -}}
            {{- $capacity = $volumeData.capacity -}}
          {{- end -}}
          {{- if $volumeData.accessModes -}}
            {{- $accessModes = $volumeData.accessModes -}}
          {{- end -}}
        {{- end }}
  accessModes: {{- toYaml $accessModes | nindent 4 }}
  capacity:
    storage: {{ $capacity | quote }}
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: {{ $objectName | quote }}
    namespace: {{ $ctx.Release.Namespace | quote }}
        {{- if $localPath }}
  hostPath:
    path: {{ $localPath | quote }}
    type: DirectoryOrCreate
        {{- end }}
  persistentVolumeReclaimPolicy: {{ $settings.persistentVolumeReclaimPolicy | quote }}
        {{- if $storageClassName }}
  storageClassName: {{ $storageClassName | quote }}
        {{- end }}
  volumeMode: {{ $volumeMode | quote }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
