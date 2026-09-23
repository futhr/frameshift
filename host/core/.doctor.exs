%{
  ignore_paths: [],
  ignore_for_refs: [],
  exception_moduledoc: true,
  failed: true,
  min_module_doc_coverage: 0,
  min_module_spec_coverage: 80,
  min_overall_doc_coverage: 75,
  min_overall_spec_coverage: 80,
  raise: false,
  reporter: Doctor.Reporters.Full
}
