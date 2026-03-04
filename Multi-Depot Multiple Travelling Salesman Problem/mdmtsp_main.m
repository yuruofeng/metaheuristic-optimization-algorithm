function mdmtsp_main(mode, algorithm, params)
%MDMTSP_MAIN 多仓库多旅行商问题统一主脚本
%   合并了 demo_optimized.m 和 main_optimized.m 的功能，支持单算法和多算法模式
%
%   调用方式：
%   1. 单算法模式：mdmtsp_main('single', 'PSO', params)
%   2. 多算法模式：mdmtsp_main('multi', {'PSO','SA','ACO','GWO'}, params)
%   3. 默认参数：mdmtsp_main() - 使用默认参数运行单算法PSO模式
%
%   输入参数：
%   mode - 运行模式：'single'（单算法）或 'multi'（多算法对比）
%   algorithm - 算法名称或算法列表
%               单算法模式：字符串，如 'PSO', 'SA', 'ACO', 'GWO'
%               多算法模式：字符串元胞数组，如 {'PSO','SA','ACO','GWO'}
%   params - 可选参数结构体，用于覆盖默认参数
%
%   示例：
%   % 单算法PSO模式
%   mdmtsp_main('single', 'PSO');
%
%   % 多算法对比模式
%   mdmtsp_main('multi', {'PSO','SA','ACO','GWO'});
%
%   % 自定义参数
%   params = struct();
%   params.num_cities = 20;
%   params.num_depots = 3;
%   mdmtsp_main('single', 'PSO', params);

% 版本信息
% 创建于 2026-02-08
% 合并自 demo_optimized.m 和 main_optimized.m

% 清除工作区并关闭所有图形窗口
clc; close all;

%% 参数解析和验证
if nargin < 1
    mode = 'single';  % 默认单算法模式
end

if nargin < 2
    if strcmp(mode, 'single')
        algorithm = 'PSO';  % 默认算法
    else
        algorithm = {'PSO', 'SA', 'ACO', 'GWO'};  % 默认算法列表
    end
end

if nargin < 3
    params = struct();  % 空参数结构体
end

% 验证模式参数
valid_modes = {'single', 'multi'};
if ~any(strcmp(mode, valid_modes))
    error('无效的模式参数。应为 ''single'' 或 ''multi''，但得到 ''%s''。', mode);
end

% 验证算法参数
if strcmp(mode, 'single')
    % 单算法模式：算法应为字符串
    if ~ischar(algorithm)
        error('单算法模式下，algorithm 参数应为字符串（如 ''PSO''）。');
    end
    valid_algorithms = {'PSO', 'SA', 'ACO', 'GWO'};
    if ~any(strcmp(algorithm, valid_algorithms))
        error('无效的算法名称 ''%s''。有效的算法：PSO, SA, ACO, GWO。', algorithm);
    end
else
    % 多算法模式：算法应为元胞数组
    if ~iscell(algorithm)
        error('多算法模式下，algorithm 参数应为字符串元胞数组（如 {''PSO'',''SA'',''ACO'',''GWO''}）。');
    end
    valid_algorithms = {'PSO', 'SA', 'ACO', 'GWO'};
    for i = 1:length(algorithm)
        if ~any(strcmp(algorithm{i}, valid_algorithms))
            error('无效的算法名称 ''%s''。有效的算法：PSO, SA, ACO, GWO。', algorithm{i});
        end
    end
end

%% 设置默认参数
default_params = get_default_parameters();
params = merge_parameters(default_params, params);

%% 显示运行配置
fprintf('========================================\n');
fprintf('多仓库多旅行商问题优化系统\n');
fprintf('========================================\n');
fprintf('运行模式: %s\n', mode);
if strcmp(mode, 'single')
    fprintf('算法: %s\n', algorithm);
else
    fprintf('算法对比: %s\n', strjoin(algorithm, ', '));
end
fprintf('城市数量: %d\n', params.num_cities);
fprintf('仓库数量: %d\n', params.num_depots);
fprintf('各仓库旅行商数量: %s\n', mat2str(params.travelers_per_depot));
fprintf('区域大小: %d\n', params.area_size);
fprintf('随机种子: %d\n', params.random_seed);
fprintf('----------------------------------------\n');

%% 生成问题实例
fprintf('生成问题实例...\n');
rng(params.random_seed);  % 设置随机种子以保证可重复性

problem = ProblemDefinition.generate_random_problem(...
    params.num_cities, ...
    params.num_depots, ...
    params.travelers_per_depot, ...
    params.area_size);

%% 运行优化
if strcmp(mode, 'single')
    % 单算法模式
    fprintf('\n运行%s算法优化...\n', algorithm);
    results = run_single_algorithm(problem, algorithm, params);
else
    % 多算法模式
    fprintf('\n运行多算法对比...\n');
    results = run_multi_algorithm_comparison(problem, algorithm, params);
end

%% 显示结果
fprintf('\n========================================\n');
fprintf('优化完成\n');
fprintf('========================================\n');

if strcmp(mode, 'single')
    fprintf('最优路径总成本: %.2f\n', results.best_cost);
    fprintf('总迭代次数: %d\n', length(results.fitness_history));
else
    fprintf('算法对比结果:\n');
    fprintf('算法\t\t最终路径长度\t迭代次数\n');
    for i = 1:length(results)
        fprintf('%s\t\t%.2f\t\t%d\n', ...
            results(i).algorithm, ...
            results(i).best_cost, ...
            length(results(i).fitness_history));
    end

    % 找出最优算法
    best_idx = 1;
    best_cost = results(1).best_cost;
    for i = 2:length(results)
        if results(i).best_cost < best_cost
            best_cost = results(i).best_cost;
            best_idx = i;
        end
    end
    fprintf('\n最优算法: %s (路径长度: %.2f)\n', ...
        results(best_idx).algorithm, best_cost);
end

fprintf('\n运行结束。\n');

end  % 主函数结束

%% 子函数定义

function default_params = get_default_parameters()
%GET_DEFAULT_PARAMETERS 获取默认参数设置
%   返回包含所有默认参数的结构体

    default_params = struct();

    % 问题参数（基于 demo_optimized.m 的默认值）
    default_params.num_cities = 15;           % 城市数量
    default_params.num_depots = 2;            % 仓库数量
    default_params.travelers_per_depot = [2, 2];  % 各仓库旅行商数量
    default_params.area_size = 200;           % 区域大小
    default_params.random_seed = 1;           % 随机种子

    % 算法通用参数
    default_params.max_iter = 1000;           % 最大迭代次数

    % PSO参数（基于 demo_optimized.m）
    default_params.pso_params = struct();
    default_params.pso_params.max_iter = 1000;
    default_params.pso_params.num_particles = 50;
    default_params.pso_params.w = 0.7;
    default_params.pso_params.c1 = 1.5;
    default_params.pso_params.c2 = 1.5;
    default_params.pso_params.enable_visualization = false;

    % SA参数（基于 demo_optimized.m）
    default_params.sa_params = struct();
    default_params.sa_params.max_iter = 1000;
    default_params.sa_params.initial_temp = 1000;
    default_params.sa_params.cooling_rate = 0.95;

    % ACO参数（基于 demo_optimized.m）
    default_params.aco_params = struct();
    default_params.aco_params.max_iter = 1000;
    default_params.aco_params.ant_num = 50;
    default_params.aco_params.q0 = 0.7;
    default_params.aco_params.rho = 0.2;
    default_params.aco_params.alpha = 1.2;
    default_params.aco_params.beta = 2;

    % GWO参数（基于 demo_optimized.m）
    default_params.gwo_params = struct();
    default_params.gwo_params.max_iter = 1000;
    default_params.gwo_params.pop_size = 50;

    % 可视化参数
    default_params.enable_visualization = true;  % 是否启用结果可视化
    default_params.save_figures = false;      % 是否保存图形文件
    default_params.figure_format = 'png';     % 图形保存格式

end

function merged = merge_parameters(default, user)
%MERGE_PARAMETERS 合并默认参数和用户参数
%   用用户提供的参数覆盖默认参数

    merged = default;
    if isempty(user)
        return;
    end

    user_fields = fieldnames(user);
    for i = 1:length(user_fields)
        field = user_fields{i};
        merged.(field) = user.(field);
    end
end

function results = run_single_algorithm(problem, algorithm, params)
%RUN_SINGLE_ALGORITHM 运行单算法优化
%   输入：
%       problem - 问题结构体
%       algorithm - 算法名称字符串
%       params - 参数结构体
%   输出：
%       results - 结果结构体

    fprintf('配置%s算法参数...\n', algorithm);

    % 根据算法获取对应的参数结构体
    switch upper(algorithm)
        case 'PSO'
            algorithm_params = params.pso_params;
            function_name = 'pso';

        case 'SA'
            algorithm_params = params.sa_params;
            function_name = 'simulated_annealing';

        case 'ACO'
            algorithm_params = params.aco_params;
            function_name = 'ant_colony_optimization';

        case 'GWO'
            algorithm_params = params.gwo_params;
            function_name = 'grey_wolf_optimization';

        otherwise
            error('未知算法: %s', algorithm);
    end

    % 确保最大迭代次数参数一致
    algorithm_params.max_iter = params.max_iter;

    % 运行算法
    fprintf('开始%s优化...\n', algorithm);
    tic;

    % 调用优化算法
    % 注意：根据OptimizationAlgorithms.pso的实现，它支持2或3个输出参数
    if strcmpi(algorithm, 'PSO') && isfield(algorithm_params, 'enable_visualization') && algorithm_params.enable_visualization
        % PSO算法支持实时可视化
        [best_routes, best_cost, fitness_history] = OptimizationAlgorithms.pso(...
            problem, algorithm_params);
    else
        % 其他算法或禁用可视化的PSO
        [best_solution, fitness_history] = feval(...
            ['OptimizationAlgorithms.' function_name], ...
            problem, algorithm_params);

        % 解码为路径
        [best_cost, best_routes] = ProblemDefinition.evaluate_solution(...
            best_solution, problem);
    end

    elapsed_time = toc;
    fprintf('%s优化完成，耗时: %.2f 秒\n', algorithm, elapsed_time);

    % 构建结果结构体
    results = struct();
    results.algorithm = algorithm;
    results.best_routes = best_routes;
    results.best_cost = best_cost;
    results.fitness_history = fitness_history;
    results.problem = problem;
    results.elapsed_time = elapsed_time;

    % 可视化结果
    if params.enable_visualization
        visualize_single_result(results, params);
    end

end

function results = run_multi_algorithm_comparison(problem, algorithms, params)
%RUN_MULTI_ALGORITHM_COMPARISON 运行多算法对比
%   输入：
%       problem - 问题结构体
%       algorithms - 算法名称元胞数组
%       params - 参数结构体
%   输出：
%       results - 结果结构体数组

    num_algorithms = length(algorithms);
    results = struct('algorithm', {}, 'best_routes', {}, ...
        'best_cost', {}, 'fitness_history', {}, 'problem', {}, 'elapsed_time', {});

    % 顺序运行各个算法
    for i = 1:num_algorithms
        alg = algorithms{i};
        fprintf('\n[%d/%d] 运行%s算法...\n', i, num_algorithms, alg);

        % 运行单个算法
        single_result = run_single_algorithm(problem, alg, params);

        % 添加到结果数组
        results(i) = single_result;
    end

    % 可视化对比结果
    if params.enable_visualization
        visualize_multi_comparison(results, algorithms, params);
    end

end

function visualize_single_result(result, params)
%VISUALIZE_SINGLE_RESULT 可视化单算法结果
%   输入：
%       result - 单个算法的结果结构体
%       params - 参数结构体

    fprintf('生成可视化结果...\n');

    % 提取问题参数用于可视化
    problem = result.problem;
    if isfield(problem, 'locations')
        locations = problem.locations;
        num_depots = problem.num_depots;
    else
        locations = [problem.depot_coords; problem.city_coords];
        num_depots = size(problem.depot_coords, 1);
    end

    % 计算旅行商到仓库的分配
    depot_traveler_counts = problem.travelers_per_depot;
    total_travelers = sum(depot_traveler_counts);

    % 预分配depot_assignment数组
    depot_assignment = zeros(1, total_travelers);
    current_idx = 1;
    for d = 1:num_depots
        count = depot_traveler_counts(d);
        depot_assignment(current_idx:current_idx+count-1) = d;
        current_idx = current_idx + count;
    end

    % 1. 绘制收敛曲线
    figure('Name', sprintf('%s算法收敛曲线', result.algorithm), ...
        'Position', [100, 100, 800, 400]);
    plot(result.fitness_history, 'b-o', 'LineWidth', 1.5);
    title(sprintf('%s算法收敛曲线', result.algorithm));
    xlabel('迭代次数');
    ylabel('总路径成本');
    grid on;

    % 2. 绘制最终路径规划
    if ~isempty(result.best_routes)
        Visualization.draw_final_routes(locations, result.best_routes, depot_assignment);
    end

    % 保存图形（如果启用）
    if params.save_figures
        save_figure(sprintf('%s_convergence', result.algorithm), params.figure_format);
        save_figure(sprintf('%s_routes', result.algorithm), params.figure_format);
    end

end

function visualize_multi_comparison(results, algorithms, params)
%VISUALIZE_MULTI_COMPARISON 可视化多算法对比结果
%   输入：
%       results - 结果结构体数组
%       algorithms - 算法名称元胞数组
%       params - 参数结构体

    fprintf('生成多算法对比可视化...\n');

    % 1. 收敛曲线对比
    convergence_histories = cell(1, length(results));
    for i = 1:length(results)
        convergence_histories{i} = results(i).fitness_history;
    end

    Visualization.plot_convergence(convergence_histories, algorithms);

    % 2. 路径规划对比
    Visualization.plot_algorithm_comparison(results, algorithms);

    % 3. 算法性能对比图（箱线图）
    figure('Name', '算法性能对比', 'Position', [100, 100, 600, 400]);
    final_costs = [results.best_cost];
    bar(final_costs);
    title('算法最终路径成本对比');
    xlabel('算法');
    ylabel('路径成本');
    set(gca, 'XTickLabel', algorithms);
    grid on;

    % 添加数值标签
    for i = 1:length(final_costs)
        text(i, final_costs(i), sprintf('%.1f', final_costs(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end

    % 保存图形（如果启用）
    if params.save_figures
        save_figure('multi_algorithm_comparison', params.figure_format);
        save_figure('multi_algorithm_routes', params.figure_format);
        save_figure('algorithm_performance', params.figure_format);
    end

end

function save_figure(name, format)
%SAVE_FIGURE 保存当前图形
%   输入：
%       name - 文件名（不含扩展名）
%       format - 文件格式（'png', 'jpg', 'pdf'等）

    % 使用datetime替代now和datestr（MATLAB推荐做法）
    timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
    filename = sprintf('%s_%s.%s', name, char(timestamp), format);
    saveas(gcf, filename);
    fprintf('图形已保存: %s\n', filename);
end