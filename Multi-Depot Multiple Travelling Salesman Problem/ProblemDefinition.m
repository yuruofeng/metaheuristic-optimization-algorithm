classdef ProblemDefinition
    % PROBLEMDEFINITION 问题定义工具类
    % 包含适应度函数、问题生成和验证相关的静态方法

    methods (Static)

        function [fitness, assignment] = mdmtsp_fitness(solution, num_depots, travelers_per_depot, ...
                depot_coords, city_coords, depot_city_dist)
            % MDMTSP_FITNESS 计算多仓库多旅行商问题的适应度
            % 输入:
            %   solution - 解向量，长度等于城市数量，每个元素在[0,1]区间
            %   num_depots - 仓库数量
            %   travelers_per_depot - 每个仓库的旅行商数量向量
            %   depot_coords - 仓库坐标矩阵 (num_depots × 2)
            %   city_coords - 城市坐标矩阵 (num_cities × 2)
            %   depot_city_dist - 仓库到城市的距离矩阵 (num_depots × num_cities)
            % 输出:
            %   fitness - 适应度值（总路径长度）
            %   assignment - 城市到旅行商的分配向量

            total_travelers = sum(travelers_per_depot);
            assignment = ceil(solution * total_travelers);
            assignment = min(max(assignment, 1), total_travelers);
            total_distance = 0;

            for traveler_idx = 1:total_travelers
                depot_idx = ceil(traveler_idx / travelers_per_depot(1)); % 简化假设每个仓库旅行商数相同
                % 实际应根据travelers_per_depot计算
                % 修正：找到旅行商对应的仓库
                cumulative = 0;
                for d = 1:num_depots
                    if traveler_idx <= cumulative + travelers_per_depot(d)
                        depot_idx = d;
                        break;
                    end
                    cumulative = cumulative + travelers_per_depot(d);
                end

                cities = find(assignment == traveler_idx);
                if isempty(cities)
                    continue;
                end

                % 计算路径长度
                if length(cities) >= 1
                    total_distance = total_distance + depot_city_dist(depot_idx, cities(1));
                    for i = 1:length(cities)-1
                        total_distance = total_distance + norm(city_coords(cities(i),:) - city_coords(cities(i+1),:));
                    end
                    total_distance = total_distance + depot_city_dist(depot_idx, cities(end));
                end
            end
            fitness = total_distance;
        end

        function problem = generate_random_problem(num_cities, num_depots, travelers_per_depot, area_size)
            % GENERATE_RANDOM_PROBLEM 生成随机多仓库多旅行商问题
            % 输入:
            %   num_cities - 城市数量
            %   num_depots - 仓库数量
            %   travelers_per_depot - 每个仓库的旅行商数量向量
            %   area_size - 区域大小 (默认100)
            % 输出:
            %   problem - 问题结构体

            if nargin < 4
                area_size = 100;
            end

            % 生成随机坐标
            rng('shuffle');
            depot_coords = rand(num_depots, 2) * area_size;
            city_coords = rand(num_cities, 2) * area_size;

            % 计算距离矩阵
            depot_city_dist = pdist2(depot_coords, city_coords);
            all_locations = [depot_coords; city_coords];
            distance_matrix = pdist2(all_locations, all_locations);

            % 构建问题结构体
            problem = struct();
            problem.locations = all_locations;
            problem.depot_coords = depot_coords;
            problem.city_coords = city_coords;
            problem.num_depots = num_depots;
            problem.num_cities = num_cities;
            problem.travelers_per_depot = travelers_per_depot;
            problem.depot_city_dist = depot_city_dist;
            problem.distance_matrix = distance_matrix;
            problem.area_size = area_size;
        end

        function is_valid = validate_solution(solution, num_depots, travelers_per_depot)
            % VALIDATE_SOLUTION 验证解的合法性
            % 输入:
            %   solution - 解向量
            %   num_depots - 仓库数量
            %   travelers_per_depot - 每个仓库的旅行商数量向量
            % 输出:
            %   is_valid - 是否有效

            total_travelers = sum(travelers_per_depot);

            % 检查解向量长度
            if length(solution) < 1
                is_valid = false;
                return;
            end

            % 检查解值范围
            if any(solution < 0) || any(solution > 1)
                is_valid = false;
                return;
            end

            % 计算分配
            assignment = ceil(solution * total_travelers);
            assignment = min(max(assignment, 1), total_travelers);

            % 检查每个旅行商是否至少分配到一个城市（可选）
            % 实际上，旅行商可以没有分配城市
            is_valid = true;
        end

        function [total_cost, routes] = evaluate_solution(solution, problem)
            % EVALUATE_SOLUTION 评估解的质量
            % 输入:
            %   solution - 解向量
            %   problem - 问题结构体
            % 输出:
            %   total_cost - 总路径成本
            %   routes - 路径元胞数组

            % 提取问题参数
            if isfield(problem, 'city_coords')
                city_coords = problem.city_coords;
                depot_coords = problem.depot_coords;
                depot_city_dist = problem.depot_city_dist;
                num_depots = size(depot_coords, 1);
                travelers_per_depot = problem.travelers_per_depot;
            else
                locations = problem.locations;
                num_depots = problem.num_depots;
                travelers_per_depot = problem.travelers_per_depot;
                num_cities = size(locations, 1) - num_depots;
                city_coords = locations(num_depots+1:end, :);
                depot_coords = locations(1:num_depots, :);
                depot_city_dist = pdist2(depot_coords, city_coords);
            end

            % 计算适应度
            [total_cost, assignment] = ProblemDefinition.mdmtsp_fitness(...
                solution, num_depots, travelers_per_depot, ...
                depot_coords, city_coords, depot_city_dist);

            % 构建路径（如果需要）
            if nargout > 1
                total_travelers = sum(travelers_per_depot);
                num_cities = size(city_coords, 1);
                routes = cell(1, total_travelers);

                for traveler_idx = 1:total_travelers
                    cities = find(assignment == traveler_idx);
                    if isempty(cities)
                        routes{traveler_idx} = [];
                        continue;
                    end

                    % 找到对应的仓库
                    cumulative = 0;
                    for d = 1:num_depots
                        if traveler_idx <= cumulative + travelers_per_depot(d)
                            depot_idx = d;
                            break;
                        end
                        cumulative = cumulative + travelers_per_depot(d);
                    end

                    % 构建路径：仓库 -> 城市 -> 仓库
                    routes{traveler_idx} = [depot_idx, cities(:)' + num_depots, depot_idx];
                end
            end
        end

    end
end