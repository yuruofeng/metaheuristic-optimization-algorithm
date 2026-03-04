classdef Utilities
    % UTILITIES 通用工具函数类
    % 包含各种辅助函数

    methods (Static)

        function index = roulette_wheel(probabilities)
            % ROULETTE_WHEEL 轮盘赌选择
            % 输入:
            %   probabilities - 概率向量（已归一化）
            % 输出:
            %   index - 选中的索引

            cumulative_prob = cumsum(probabilities);
            index = find(cumulative_prob >= rand(), 1);
        end

        function child = crossover(parent1, parent2, method)
            % CROSSOVER 交叉操作
            % 输入:
            %   parent1 - 父代1
            %   parent2 - 父代2
            %   method - 交叉方法 ('single_point', 'uniform', 'arithmetic')
            % 输出:
            %   child - 子代

            if nargin < 3
                method = 'arithmetic';
            end

            n = length(parent1);
            child = zeros(size(parent1));

            switch method
                case 'single_point'
                    point = randi(n-1);
                    child(1:point) = parent1(1:point);
                    child(point+1:end) = parent2(point+1:end);

                case 'uniform'
                    mask = rand(1, n) > 0.5;
                    child(mask) = parent1(mask);
                    child(~mask) = parent2(~mask);

                case 'arithmetic'
                    alpha = rand();
                    child = alpha * parent1 + (1 - alpha) * parent2;

                otherwise
                    error('未知的交叉方法: %s', method);
            end
        end

        function mutated = mutate(individual, mutation_rate, mutation_scale)
            % MUTATE 变异操作
            % 输入:
            %   individual - 个体
            %   mutation_rate - 变异概率
            %   mutation_scale - 变异尺度
            % 输出:
            %   mutated - 变异后的个体

            if nargin < 2
                mutation_rate = 0.1;
            end
            if nargin < 3
                mutation_scale = 0.1;
            end

            mutated = individual;
            n = length(individual);
            mutation_mask = rand(1, n) < mutation_rate;

            if any(mutation_mask)
                mutation_values = randn(1, sum(mutation_mask)) * mutation_scale;
                mutated(mutation_mask) = mutated(mutation_mask) + mutation_values;
                mutated = max(min(mutated, 1), 0); % 保持在[0,1]范围内
            end
        end

        function [fronts, ranks] = non_domination_sort(population, fitness_values)
            % NON_DOMINATION_SORT 非支配排序
            % 输入:
            %   population - 种群矩阵
            %   fitness_values - 适应度矩阵（每行是一个个体的多目标适应度）
            % 输出:
            %   fronts - 前沿元胞数组，每个元素是一个前沿的个体索引
            %   ranks - 每个个体的前沿等级

            num_individuals = size(population, 1);
            dominated_set = cell(num_individuals, 1);
            domination_count = zeros(num_individuals, 1);
            ranks = zeros(num_individuals, 1);

            % 计算支配关系
            for i = 1:num_individuals
                for j = 1:num_individuals
                    if i == j
                        continue;
                    end

                    if all(fitness_values(i, :) <= fitness_values(j, :)) && ...
                       any(fitness_values(i, :) < fitness_values(j, :))
                        dominated_set{i} = [dominated_set{i}, j];
                    elseif all(fitness_values(j, :) <= fitness_values(i, :)) && ...
                           any(fitness_values(j, :) < fitness_values(i, :))
                        domination_count(i) = domination_count(i) + 1;
                    end
                end
            end

            % 找到第一前沿（支配计数为0的个体）
            current_front = find(domination_count == 0);
            fronts = {};
            current_rank = 1;

            while ~isempty(current_front)
                fronts{current_rank} = current_front;
                ranks(current_front) = current_rank;

                next_front = [];
                for i = 1:length(current_front)
                    idx = current_front(i);
                    for j = 1:length(dominated_set{idx})
                        dominated_idx = dominated_set{idx}(j);
                        domination_count(dominated_idx) = domination_count(dominated_idx) - 1;
                        if domination_count(dominated_idx) == 0
                            next_front = [next_front, dominated_idx];
                        end
                    end
                end

                current_front = unique(next_front);
                current_rank = current_rank + 1;
            end
        end

        function normalized = normalize_matrix(matrix, mode)
            % NORMALIZE_MATRIX 矩阵归一化
            % 输入:
            %   matrix - 输入矩阵
            %   mode - 归一化模式 ('minmax', 'zscore', 'softmax')
            % 输出:
            %   normalized - 归一化后的矩阵

            if nargin < 2
                mode = 'minmax';
            end

            switch mode
                case 'minmax'
                    min_val = min(matrix(:));
                    max_val = max(matrix(:));
                    if max_val > min_val
                        normalized = (matrix - min_val) / (max_val - min_val);
                    else
                        normalized = zeros(size(matrix));
                    end

                case 'zscore'
                    mu = mean(matrix(:));
                    sigma = std(matrix(:));
                    if sigma > 0
                        normalized = (matrix - mu) / sigma;
                    else
                        normalized = zeros(size(matrix));
                    end

                case 'softmax'
                    exp_matrix = exp(matrix - max(matrix(:)));
                    normalized = exp_matrix / sum(exp_matrix(:));

                otherwise
                    error('未知的归一化模式: %s', mode);
            end
        end

        function distance = euclidean_distance(point1, point2)
            % EUCLIDEAN_DISTANCE 计算欧几里得距离
            % 输入:
            %   point1 - 点1坐标
            %   point2 - 点2坐标
            % 输出:
            %   distance - 欧几里得距离

            distance = norm(point1 - point2);
        end

        function [sorted_values, sorted_indices] = sort_with_indices(values, direction)
            % SORT_WITH_INDICES 带索引的排序
            % 输入:
            %   values - 待排序的值
            %   direction - 排序方向 ('ascend' 或 'descend')
            % 输出:
            %   sorted_values - 排序后的值
            %   sorted_indices - 排序后的索引

            if nargin < 2
                direction = 'ascend';
            end

            [sorted_values, sorted_indices] = sort(values, direction);
        end

    end
end