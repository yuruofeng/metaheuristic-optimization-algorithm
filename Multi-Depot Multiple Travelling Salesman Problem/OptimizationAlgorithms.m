classdef OptimizationAlgorithms
    % OPTIMIZATIONALGORITHMS 优化算法静态类
    % 包含多种优化算法：PSO、SA、ACO、GWO等

    methods (Static)

        function varargout = pso(problem, algorithm_params)
            % PSO 粒子群优化算法
            % 输入:
            %   problem - 问题结构体，包含以下字段:
            %       locations - 所有节点坐标矩阵 (num_depots + num_cities) × 2
            %       num_depots - 仓库数量
            %       depot_traveler_counts - 每个仓库的旅行商数量向量
            %       distance_matrix - 距离矩阵 (可选，如果没有则自动计算)
            %   algorithm_params - 算法参数结构体，包含以下字段:
            %       num_particles - 粒子数量
            %       max_iter - 最大迭代次数
            %       w - 惯性权重 (可选，默认0.729)
            %       c1 - 个体学习因子 (可选，默认1.49445)
            %       c2 - 社会学习因子 (可选，默认1.49445)
            %       enable_visualization - 是否启用可视化 (可选，默认false)
            % 输出 (根据 nargout):
            %   当 nargout == 2: [best_solution, fitness_history]
            %   当 nargout == 3: [best_routes, best_cost, fitness_history]
            %   其中:
            %       best_solution - 最优解向量（编码形式）
            %       fitness_history - 收敛历史向量
            %       best_routes - 最优路径元胞数组
            %       best_cost - 最优路径总成本

            % 参数验证和默认值设置
            if nargin < 2
                algorithm_params = struct();
            end

            % 提取问题参数
            if isfield(problem, 'city_coords')
                % 旧格式：包含 city_coords, depot_coords, depot_city_dist, travelers_per_depot
                city_coords = problem.city_coords;
                depot_coords = problem.depot_coords;
                depot_city_dist = problem.depot_city_dist;
                num_cities = size(city_coords, 1);
                num_depots = size(depot_coords, 1);
                depot_traveler_counts = problem.travelers_per_depot;
                locations = [depot_coords; city_coords];
            else
                % 新格式：包含 locations, num_depots，以及 depot_traveler_counts 或 travelers_per_depot
                locations = problem.locations;
                num_depots = problem.num_depots;

                % 检查使用哪个字段名
                if isfield(problem, 'depot_traveler_counts')
                    depot_traveler_counts = problem.depot_traveler_counts;
                elseif isfield(problem, 'travelers_per_depot')
                    depot_traveler_counts = problem.travelers_per_depot;
                else
                    error('问题结构体必须包含 depot_traveler_counts 或 travelers_per_depot 字段');
                end

                num_cities = size(locations, 1) - num_depots;
                city_coords = locations(num_depots+1:end, :);
                depot_coords = locations(1:num_depots, :);
                depot_city_dist = pdist2(depot_coords, city_coords);
            end

            % 计算距离矩阵（如果未提供）
            if isfield(problem, 'distance_matrix')
                distance_matrix = problem.distance_matrix;
            else
                distance_matrix = pdist2(locations, locations);
            end

            % 设置算法参数默认值
            params = struct();
            params.num_particles = 200;
            params.max_iter = 200;
            params.w = 0.729;
            params.c1 = 1.49445;
            params.c2 = 1.49445;
            params.enable_visualization = false;

            % 用用户提供的参数覆盖默认值
            param_fields = fieldnames(algorithm_params);
            for i = 1:length(param_fields)
                field = param_fields{i};
                params.(field) = algorithm_params.(field);
            end

            % 初始化参数
            num_cities = size(locations, 1) - num_depots;
            total_travelers = sum(depot_traveler_counts);
            depot_nodes = 1:num_depots;
            city_nodes = (num_depots+1):(num_depots+num_cities);

            % 初始化旅行商到仓库的分配
            depot_assignment = [];
            for d = 1:num_depots
                depot_assignment = [depot_assignment, d * ones(1, depot_traveler_counts(d))];
            end

            % PSO初始化
            particles.position = rand(params.num_particles, num_cities) * total_travelers;
            particles.velocity = zeros(params.num_particles, num_cities);
            particles.best_position = particles.position;
            particles.best_cost = inf(params.num_particles, 1);
            global_best_cost = inf;
            global_best_position = [];
            best_routes = cell(1, total_travelers);
            convergence = zeros(1, params.max_iter);

            % 创建可视化窗口（如果启用）
            if params.enable_visualization
                fig = figure('Position', [100 100 1200 500]);
                subplot(1,2,1);
                hold on;
                title('实时路径优化');
                xlabel('X坐标'); ylabel('Y坐标');
                plot(locations(depot_nodes,1), locations(depot_nodes,2),...
                    'ks', 'MarkerSize', 12, 'LineWidth', 2);
                plot(locations(city_nodes,1), locations(city_nodes,2),...
                    'bo', 'MarkerSize', 8);
                subplot(1,2,2);
                hold on;
                title('收敛曲线');
                xlabel('迭代次数'); ylabel('总成本');
            end

            % 主优化循环
            for iter = 1:params.max_iter
                for p = 1:params.num_particles
                    % 解码当前粒子
                    [total_cost, routes] = PathUtilities.decode_particle(...
                        particles.position(p,:), locations, distance_matrix, ...
                        num_depots, depot_traveler_counts, depot_assignment);

                    % 更新最优解
                    if total_cost < particles.best_cost(p)
                        particles.best_position(p,:) = particles.position(p,:);
                        particles.best_cost(p) = total_cost;
                    end
                    if total_cost < global_best_cost
                        global_best_cost = total_cost;
                        global_best_position = particles.position(p,:);
                        best_routes = routes;
                    end
                end

                % 更新粒子速度和位置
                for p = 1:params.num_particles
                    r1 = rand(1, num_cities);
                    r2 = rand(1, num_cities);
                    particles.velocity(p,:) = params.w * particles.velocity(p,:) + ...
                        params.c1 * r1 .* (particles.best_position(p,:) - particles.position(p,:)) + ...
                        params.c2 * r2 .* (global_best_position - particles.position(p,:));

                    % 速度限幅
                    particles.velocity(p,:) = max(min(particles.velocity(p,:), total_travelers/2), -total_travelers/2);

                    % 更新位置
                    particles.position(p,:) = particles.position(p,:) + particles.velocity(p,:);
                    particles.position(p,:) = max(particles.position(p,:), 0);
                    particles.position(p,:) = min(particles.position(p,:), total_travelers - 1e-6);
                end

                % 记录收敛数据
                convergence(iter) = global_best_cost;

                % 更新可视化（如果启用）
                if params.enable_visualization && (mod(iter, 5) == 0 || iter == 1)
                    % 这里可以调用可视化类的方法
                    fprintf('迭代 %3d: 当前最优成本 = %.2f\n', iter, global_best_cost);
                else
                    if mod(iter, 10) == 0
                        fprintf('迭代 %3d: 当前最优成本 = %.2f\n', iter, global_best_cost);
                    end
                end
            end

            % 根据nargout设置返回值
            if nargout == 2
                % 返回解向量和适应度历史
                varargout{1} = global_best_position;
                varargout{2} = convergence;
            elseif nargout == 3
                % 返回路径、成本和适应度历史
                varargout{1} = best_routes;
                varargout{2} = global_best_cost;
                varargout{3} = convergence;
            else
                error('不支持的输出参数数量。支持2或3个输出参数。');
            end
        end

        function [best_solution, fitness_history] = simulated_annealing(problem, algorithm_params)
            % SIMULATED_ANNEALING 模拟退火算法
            % 输入:
            %   problem - 问题结构体
            %   algorithm_params - 算法参数结构体
            % 输出:
            %   best_solution - 最优解向量
            %   fitness_history - 适应度历史

            % 参数验证和默认值设置
            if nargin < 2
                algorithm_params = struct();
            end

            % 提取问题参数
            if isfield(problem, 'city_coords')
                city_coords = problem.city_coords;
                depot_coords = problem.depot_coords;
                depot_city_dist = problem.depot_city_dist;
                num_cities = size(city_coords, 1);
                num_depots = size(depot_coords, 1);
                travelers_per_depot = problem.travelers_per_depot;
            else
                % 从统一格式转换
                locations = problem.locations;
                num_depots = problem.num_depots;

                % 检查使用哪个字段名
                if isfield(problem, 'depot_traveler_counts')
                    depot_traveler_counts = problem.depot_traveler_counts;
                elseif isfield(problem, 'travelers_per_depot')
                    depot_traveler_counts = problem.travelers_per_depot;
                else
                    error('问题结构体必须包含 depot_traveler_counts 或 travelers_per_depot 字段');
                end

                num_cities = size(locations, 1) - num_depots;
                city_coords = locations(num_depots+1:end, :);
                depot_coords = locations(1:num_depots, :);
                depot_city_dist = pdist2(depot_coords, city_coords);
                travelers_per_depot = depot_traveler_counts;
            end

            total_travelers = sum(travelers_per_depot);

            % 设置算法参数默认值
            params = struct();
            params.max_iter = 1000;
            params.initial_temp = 1000;
            params.cooling_rate = 0.95;

            % 用用户提供的参数覆盖默认值
            param_fields = fieldnames(algorithm_params);
            for i = 1:length(param_fields)
                field = param_fields{i};
                params.(field) = algorithm_params.(field);
            end

            % 初始化
            temperature = params.initial_temp;
            current_solution = rand(1, num_cities);
            [current_fitness, ~] = ProblemDefinition.mdmtsp_fitness(...
                current_solution, num_depots, travelers_per_depot, ...
                depot_coords, city_coords, depot_city_dist);
            best_solution = current_solution;
            best_fitness = current_fitness;
            fitness_history = zeros(params.max_iter, 1);

            % 主循环
            for iter = 1:params.max_iter
                % 生成邻域解
                new_solution = current_solution;
                city_idx = randi(num_cities);
                new_depot = mod(ceil(new_solution(city_idx) * total_travelers + randi(total_travelers-1)) - 1, total_travelers) + 1;
                new_solution(city_idx) = (new_depot - 1 + rand()) / total_travelers;

                % 计算适应度
                [new_fitness, ~] = ProblemDefinition.mdmtsp_fitness(...
                    new_solution, num_depots, travelers_per_depot, ...
                    depot_coords, city_coords, depot_city_dist);
                delta = new_fitness - current_fitness;

                % Metropolis准则
                if delta < 0 || exp(-delta / temperature) > rand()
                    current_solution = new_solution;
                    current_fitness = new_fitness;
                    if current_fitness < best_fitness
                        best_solution = current_solution;
                        best_fitness = current_fitness;
                    end
                end

                % 记录历史
                fitness_history(iter) = best_fitness;

                % 降温
                temperature = temperature * params.cooling_rate;

                % 显示进度
                if mod(iter, 50) == 0
                    fprintf('SA 迭代 %04d | 温度: %7.1f | 当前最优: %.2f\n', ...
                        iter, temperature, best_fitness);
                end
            end
        end

        function [best_solution, fitness_history] = ant_colony_optimization(problem, algorithm_params)
            % ANT_COLONY_OPTIMIZATION 蚁群优化算法
            % 输入:
            %   problem - 问题结构体
            %   algorithm_params - 算法参数结构体
            % 输出:
            %   best_solution - 最优解向量
            %   fitness_history - 适应度历史

            % 参数验证和默认值设置
            if nargin < 2
                algorithm_params = struct();
            end

            % 提取问题参数
            if isfield(problem, 'city_coords')
                city_coords = problem.city_coords;
                depot_coords = problem.depot_coords;
                depot_city_dist = problem.depot_city_dist;
                num_cities = size(city_coords, 1);
                num_depots = size(depot_coords, 1);
                travelers_per_depot = problem.travelers_per_depot;
            else
                % 从统一格式转换
                locations = problem.locations;
                num_depots = problem.num_depots;

                % 检查使用哪个字段名
                if isfield(problem, 'depot_traveler_counts')
                    depot_traveler_counts = problem.depot_traveler_counts;
                elseif isfield(problem, 'travelers_per_depot')
                    depot_traveler_counts = problem.travelers_per_depot;
                else
                    error('问题结构体必须包含 depot_traveler_counts 或 travelers_per_depot 字段');
                end

                num_cities = size(locations, 1) - num_depots;
                city_coords = locations(num_depots+1:end, :);
                depot_coords = locations(1:num_depots, :);
                depot_city_dist = pdist2(depot_coords, city_coords);
                travelers_per_depot = depot_traveler_counts;
            end

            total_travelers = sum(travelers_per_depot);

            % 设置算法参数默认值
            params = struct();
            params.max_iter = 1000;
            params.ant_num = 50;
            params.q0 = 0.7;
            params.rho = 0.2;
            params.alpha = 1.2;
            params.beta = 2;

            % 用用户提供的参数覆盖默认值
            param_fields = fieldnames(algorithm_params);
            for i = 1:length(param_fields)
                field = param_fields{i};
                params.(field) = algorithm_params.(field);
            end

            % 初始化信息素矩阵
            pheromone = ones(total_travelers, num_cities) * 0.1;
            best_solution = rand(1, num_cities);
            best_fitness = inf;
            fitness_history = zeros(params.max_iter, 1);

            calculate_fitness = @(x) ProblemDefinition.mdmtsp_fitness(...
                x, num_depots, travelers_per_depot, ...
                depot_coords, city_coords, depot_city_dist);

            % 主循环
            for iter = 1:params.max_iter
                % 蚂蚁构建解
                ant_solutions = zeros(params.ant_num, num_cities);
                ant_fitness = inf(params.ant_num, 1);

                for ant = 1:params.ant_num
                    % 概率选择旅行商分配
                    solution = zeros(1, num_cities);
                    for city = 1:num_cities
                        probabilities = (pheromone(:, city) .^ params.alpha) .* ...
                            (1 ./ depot_city_dist(:, city)') .^ params.beta;
                        probabilities = probabilities / sum(probabilities);

                        if rand < params.q0
                            [~, selected] = max(probabilities);
                        else
                            selected = Utilities.roulette_wheel(probabilities);
                        end
                        solution(city) = (selected - 1 + rand()) / total_travelers;
                    end

                    [fitness, ~] = calculate_fitness(solution);
                    ant_solutions(ant, :) = solution;
                    ant_fitness(ant) = fitness;

                    % 更新最优解
                    if fitness < best_fitness
                        best_solution = solution;
                        best_fitness = fitness;
                    end
                end

                % 更新信息素
                pheromone = (1 - params.rho) * pheromone;
                [~, idx] = sort(ant_fitness);
                for i = 1:ceil(params.ant_num / 5)
                    solution = ant_solutions(idx(i), :);
                    [~, assign] = calculate_fitness(solution);
                    for city = 1:num_cities
                        k = assign(city);
                        pheromone(k, city) = pheromone(k, city) + 1 / ant_fitness(idx(i));
                    end
                end

                fitness_history(iter) = best_fitness;

                % 显示进度
                if mod(iter, 50) == 0
                    fprintf('ACO 迭代 %03d | 当前最优: %.2f\n', iter, best_fitness);
                end
            end
        end

        function [best_solution, fitness_history] = grey_wolf_optimization(problem, algorithm_params)
            % GREY_WOLF_OPTIMIZATION 灰狼优化算法
            % 输入:
            %   problem - 问题结构体
            %   algorithm_params - 算法参数结构体
            % 输出:
            %   best_solution - 最优解向量
            %   fitness_history - 适应度历史

            % 参数验证和默认值设置
            if nargin < 2
                algorithm_params = struct();
            end

            % 提取问题参数
            if isfield(problem, 'city_coords')
                city_coords = problem.city_coords;
                depot_coords = problem.depot_coords;
                depot_city_dist = problem.depot_city_dist;
                num_cities = size(city_coords, 1);
                num_depots = size(depot_coords, 1);
                travelers_per_depot = problem.travelers_per_depot;
            else
                % 从统一格式转换
                locations = problem.locations;
                num_depots = problem.num_depots;

                % 检查使用哪个字段名
                if isfield(problem, 'depot_traveler_counts')
                    depot_traveler_counts = problem.depot_traveler_counts;
                elseif isfield(problem, 'travelers_per_depot')
                    depot_traveler_counts = problem.travelers_per_depot;
                else
                    error('问题结构体必须包含 depot_traveler_counts 或 travelers_per_depot 字段');
                end

                num_cities = size(locations, 1) - num_depots;
                city_coords = locations(num_depots+1:end, :);
                depot_coords = locations(1:num_depots, :);
                depot_city_dist = pdist2(depot_coords, city_coords);
                travelers_per_depot = depot_traveler_counts;
            end

            total_travelers = sum(travelers_per_depot);

            % 设置算法参数默认值
            params = struct();
            params.max_iter = 1000;
            params.pop_size = 50;

            % 用用户提供的参数覆盖默认值
            param_fields = fieldnames(algorithm_params);
            for i = 1:length(param_fields)
                field = param_fields{i};
                params.(field) = algorithm_params.(field);
            end

            % 初始化狼群
            population = rand(params.pop_size, num_cities);
            fitness = inf(params.pop_size, 1);
            fitness_history = zeros(params.max_iter, 1);

            calculate_fitness = @(x) ProblemDefinition.mdmtsp_fitness(...
                x, num_depots, travelers_per_depot, ...
                depot_coords, city_coords, depot_city_dist);

            % 计算初始适应度
            for i = 1:params.pop_size
                [fitness(i), ~] = calculate_fitness(population(i, :));
            end

            [sorted_fitness, sorted_idx] = sort(fitness);
            alpha = population(sorted_idx(1), :);
            beta = population(sorted_idx(2), :);
            delta = population(sorted_idx(3), :);
            best_solution = alpha;
            best_fitness = sorted_fitness(1);

            % 主循环
            for iter = 1:params.max_iter
                a = 2 - iter * (2 / params.max_iter);  % 线性递减

                for i = 1:params.pop_size
                    % 更新位置
                    r1 = rand(1, num_cities);
                    r2 = rand(1, num_cities);
                    A1 = 2 * a .* r1 - a;
                    C1 = 2 * r2;
                    D_alpha = abs(C1 .* alpha - population(i, :));
                    X1 = alpha - A1 .* D_alpha;

                    r1 = rand(1, num_cities);
                    r2 = rand(1, num_cities);
                    A2 = 2 * a .* r1 - a;
                    C2 = 2 * r2;
                    D_beta = abs(C2 .* beta - population(i, :));
                    X2 = beta - A2 .* D_beta;

                    r1 = rand(1, num_cities);
                    r2 = rand(1, num_cities);
                    A3 = 2 * a .* r1 - a;
                    C3 = 2 * r2;
                    D_delta = abs(C3 .* delta - population(i, :));
                    X3 = delta - A3 .* D_delta;

                    new_position = (X1 + X2 + X3) / 3;
                    new_position = max(min(new_position, 1), 0);

                    % 评估新位置
                    [new_fitness, ~] = calculate_fitness(new_position);

                    % 更新个体
                    if new_fitness < fitness(i)
                        population(i, :) = new_position;
                        fitness(i) = new_fitness;
                    end
                end

                % 更新alpha, beta, delta
                [sorted_fitness, sorted_idx] = sort(fitness);
                alpha = population(sorted_idx(1), :);
                beta = population(sorted_idx(2), :);
                delta = population(sorted_idx(3), :);

                % 更新全局最优
                if sorted_fitness(1) < best_fitness
                    best_solution = alpha;
                    best_fitness = sorted_fitness(1);
                end

                fitness_history(iter) = best_fitness;

                % 显示进度
                if mod(iter, 50) == 0
                    fprintf('GWO 迭代 %03d | 当前最优: %.2f\n', iter, best_fitness);
                end
            end
        end

    end
end