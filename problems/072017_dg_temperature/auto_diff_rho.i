flow_velocity=21.7 # cm/s. See MSRE-properties.ods
nt_scale=1e13
ini_temp=922
diri_temp=922
sigma_val=.6

[GlobalParams]
  num_groups = 2
  num_precursor_groups = 6
  use_exp_form = false
  group_fluxes = 'group1 group2'
  temperature = temp
  sss2_input = false
  pre_concs = 'pre1 pre2 pre3 pre4 pre5 pre6'
  account_delayed = true
  gamma = .0144 # Cammi .0144
  nt_scale = ${nt_scale}
[]

[Mesh]
  file = '2d_lattice_structured.msh'
[]

[Problem]
  coord_type = RZ
[]

[Variables]
  [./group1]
    order = FIRST
    family = LAGRANGE
    initial_condition = 1
    scaling = 1e4
  [../]
  [./group2]
    order = FIRST
    family = LAGRANGE
    initial_condition = 1
    scaling = 1e4
  [../]
  [./temp]
    initial_condition = ${ini_temp}
    scaling = 1e-4
    order = FIRST
    family = MONOMIAL
  [../]
[]

[AuxVariables]
  [./power_density]
    order = CONSTANT
    family = MONOMIAL
  [../]
[]

[Precursors]
  [./pres]
    var_name_base = pre
    block = 'fuel'
    outlet_boundaries = 'fuel_tops'
    u_def = 0
    v_def = ${flow_velocity}
    w_def = 0
    nt_exp_form = false
    family = MONOMIAL
    order = CONSTANT
    # jac_test = true
  [../]
[]

[Kernels]
  # Neutronics
  [./time_group1]
    type = NtTimeDerivative
    variable = group1
    group_number = 1
  [../]
  [./diff_group1]
    type = GroupDiffusion
    variable = group1
    group_number = 1
  [../]
  [./sigma_r_group1]
    type = SigmaR
    variable = group1
    group_number = 1
  [../]
  [./fission_source_group1]
    type = CoupledFissionKernel
    variable = group1
    group_number = 1
  [../]
  [./delayed_group1]
    type = DelayedNeutronSource
    variable = group1
  [../]
  [./inscatter_group1]
    type = InScatter
    variable = group1
    group_number = 1
  [../]
  [./diff_group2]
    type = GroupDiffusion
    variable = group2
    group_number = 2
  [../]
  [./sigma_r_group2]
    type = SigmaR
    variable = group2
    group_number = 2
  [../]
  [./time_group2]
    type = NtTimeDerivative
    variable = group2
    group_number = 2
  [../]
  [./fission_source_group2]
    type = CoupledFissionKernel
    variable = group2
    group_number = 2
  [../]
  [./inscatter_group2]
    type = InScatter
    variable = group2
    group_number = 2
  [../]

  # Temperature
  [./temp_time_derivative]
    type = MatINSTemperatureTimeDerivative
    variable = temp
  [../]
  [./temp_source_fuel]
    type = TransientFissionHeatSource
    variable = temp
    block = 'fuel'
  [../]
  [./temp_source_mod]
    type = GammaHeatSource
    variable = temp
    block = 'moder'
    average_fission_heat = 'average_fission_heat'
  [../]
  [./temp_diffusion]
    type = MatDiffusion
    diffusivity = 'k'
    variable = temp
  [../]
  [./temp_advection_fuel]
    type = ConservativeTemperatureAdvection
    velocity = '0 ${flow_velocity} 0'
    variable = temp
    block = 'fuel'
  [../]
[]

[DGKernels]
  [./temp_advection_fuel]
    block = 'fuel'
    type = DGTemperatureAdvection
    variable = temp
    velocity = '0 ${flow_velocity} 0'
  [../]
  [./temp_diffusion]
    type = DGDiffusion
    variable = temp
    sigma = ${sigma_val}
    epsilon = -1
    diff = 'k'
  [../]
[]

[BCs]
  [./vacuum_group1]
    type = VacuumConcBC
    boundary = 'fuel_bottoms fuel_tops moder_bottoms moder_tops outer_wall'
    variable = group1
  [../]
  [./vacuum_group2]
    type = VacuumConcBC
    boundary = 'fuel_bottoms fuel_tops moder_bottoms moder_tops outer_wall'
    variable = group2
  [../]
  [./temp_dirichlet_diffusion_inlet]
    boundary = 'fuel_bottoms'
    type = DGDiffusionPostprocessorDirichletBC
    variable = temp
    sigma = ${sigma_val}
    epsilon = -1
    diffusivity = 'k'
    postprocessor = coreEndTemp
    offset = -50
  [../]
  [./temp_advection_inlet]
    boundary = 'fuel_bottoms'
    type = PostprocessorTemperatureInflowBC
    variable = temp
    uu = 0
    vv = ${flow_velocity}
    ww = 0
    postprocessor = coreEndTemp
    offset = -50
  [../]
  # [./temp_diri_cg]
  #   boundary = 'moder_bottoms fuel_bottoms outer_wall'
  #   type = FunctionDirichletBC
  #   function = 'temp_bc_func'
  #   variable = temp
  # [../]
  [./temp_advection_outlet]
    boundary = 'fuel_tops'
    type = TemperatureOutflowBC
    variable = temp
    velocity = '0 ${flow_velocity} 0'
  [../]
[]

[AuxKernels]
  [./fuel]
    block = 'fuel'
    type = FissionHeatSourceTransientAux
    variable = power_density
  [../]
  [./moderator]
    block = 'moder'
    type = ModeratorHeatSourceTransientAux
    average_fission_heat = 'average_fission_heat'
    variable = power_density
  [../]
[]

[Functions]
  [./temp_bc_func]
    type = ParsedFunction
    value = '${ini_temp} - (${ini_temp} - ${diri_temp}) * tanh(t/1e-2)'
  [../]
[]

[Materials]
  [./fuel]
    type = GenericMoltresMaterial
    property_tables_root = '../../property_file_dir/newt_msre_fuel_'
    interp_type = 'spline'
    block = 'fuel'
    prop_names = 'k cp'
    prop_values = '.0553 1967' # Robertson MSRE technical report @ 922 K
    peak_power_density = peak_power_density
    controller_gain = 0
  [../]
  [./rho_fuel]
    type = DerivativeParsedMaterial
    f_name = rho
    function = '2.146e-3 * exp(-1.8 * 1.18e-4 * (temp - 922))'
    args = 'temp'
    derivative_order = 1
    block = 'fuel'
  [../]
  [./moder]
    type = GenericMoltresMaterial
    property_tables_root = '../../property_file_dir/newt_msre_mod_'
    interp_type = 'spline'
    prop_names = 'k cp'
    prop_values = '.312 1760' # Cammi 2011 at 908 K
    block = 'moder'
    peak_power_density = peak_power_density
    controller_gain = 0
  [../]
  [./rho_moder]
    type = DerivativeParsedMaterial
    f_name = rho
    function = '1.86e-3 * exp(-1.8 * 1.0e-5 * (temp - 922))'
    args = 'temp'
    derivative_order = 1
    block = 'moder'
  [../]
[]

[Executioner]
  type = Transient
  end_time = 10000

  nl_rel_tol = 1e-6
  nl_abs_tol = 6e-6

  solve_type = 'PJFNK'
  line_search = none
  petsc_options = '-snes_converged_reason -ksp_converged_reason -snes_linesearch_monitor'
  petsc_options_iname = '-pc_type'
  petsc_options_value = 'lu'

  nl_max_its = 30
  l_max_its = 100

  dtmin = 1e-5
  [./TimeStepper]
    type = IterationAdaptiveDT
    dt = 1e-3
    cutback_factor = 0.4
    growth_factor = 1.2
    optimal_iterations = 20
  [../]
[]

[Preconditioning]
  [./SMP]
    type = SMP
    full = true
  [../]
[]

[Postprocessors]
  [./group1_current]
    type = IntegralNewVariablePostprocessor
    variable = group1
    outputs = 'console csv'
  [../]
  [./group1_old]
    type = IntegralOldVariablePostprocessor
    variable = group1
    outputs = 'console csv'
  [../]
  [./multiplication]
    type = DivisionPostprocessor
    value1 = group1_current
    value2 = group1_old
    outputs = 'console csv'
  [../]
  [./temp_fuel]
    type = ElementAverageValue
    variable = temp
    block = 'fuel'
    outputs = 'csv console'
  [../]
  [./temp_moder]
    type = ElementAverageValue
    variable = temp
    block = 'moder'
    outputs = 'csv console'
  [../]
  [./average_fission_heat]
    type = AverageFissionHeat
    execute_on = 'linear nonlinear'
    outputs = 'csv console'
    block = 'fuel'
  [../]
  [./coreEndTemp]
    type = SideAverageValue
    variable = temp
    boundary = 'fuel_tops'
    outputs = 'csv console'
    execute_on = 'linear nonlinear'
  [../]
[]

[VectorPostprocessors]
  [./outlet_temps]
    type = LineValueSampler
    start_point = '0 153 0'
    end_point = '72.5 153 0'
    num_points = 1000
    variable = temp
    sort_by = 'x'
    outputs = 'csv'
  [../]
[]

[Outputs]
  perf_graph = true
  print_linear_residuals = true
  [./csv]
    type = CSV
    execute_on = 'final'
  [../]
  exodus = true
[]

[Debug]
  show_var_residual_norms = true
[]

# [ICs]
#   [./temp_ic]
#     type = RandomIC
#     variable = temp
#     min = 922
#     max = 1022
#   [../]
#   [./group1_ic]
#     type = RandomIC
#     variable = group1
#     min = .5
#     max = 1.5
#   [../]
#   [./group2_ic]
#     type = RandomIC
#     variable = group2
#     min = .5
#     max = 1.5
#   [../]
# []
