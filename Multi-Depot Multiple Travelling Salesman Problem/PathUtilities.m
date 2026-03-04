classdef PathUtilities
    % PATHUTILITIES 路径处理工具类
    % 包含路径优化、成本计算和解码相关的静态方法

    methods (Static)

        function optimized_route = two_opt(route, distance_matrix)
            % TWO_OPT 2-opt局部优化算法
            % 输入:
            %   route - 路径节点索引向量
            %   distance_matrix - 距离矩阵
            % 输出:
            %   optimized_route - 优化后的路径

            improved = true;
            n = length(route);
            best_cost = PathUtilities.calculate_route_cost(route, distance_matrix);

            while improved
                improved = false;
                for i = 2:n-2
                    for j = i+1:n-1
                        % 反转路径段
                        new_route = [route(1:i-1); flip(route(i:j)); route(j+1:end)];
                        new_cost = PathUtilities.calculate_route_cost(new_route, distance_matrix);
                        if new_cost < best_cost
                            route = new_route;
                            best_cost = new_cost;
                            improved = true;
                            break;
                        end
                    end
                    if improved
                        break;
                    end
                end
            end
            optimized_route = route;
        end

        function cost = calculate_route_cost(route, distance_matrix)
            % CALCULATE_ROUTE_COST 计算路径总成本
            % 输入:
            %   route - 路径节点索引向量
            %   distance_matrix - 距离矩阵
            % 输出:
            %   cost - 路径总成本

            cost = 0;
            for i = 1:length(route)-1
                cost = cost + distance_matrix(route(i), route(i+1));
            end
        end

        function [total_cost, routes] = decode_particle(position, locations, distance_matrix, ...
                num_depots, depot_traveler_counts, depot_assignment)
            % DECODE_PARTICLE 解码粒子位置为路径
            % 输入:
            %   position - 粒子位置向量
            %   locations - 所有节点坐标矩阵
            %   distance_matrix - 距离矩阵
            %   num_depots - 仓库数量
            %   depot_traveler_counts - 每个仓库的旅行商数量向量
            %   depot_assignment - 旅行商到仓库的分配向量
            % 输出:
            %   total_cost - 总路径成本
            %   routes - 各旅行商路径的元胞数组

            total_travelers = sum(depot_traveler_counts);
            num_cities = length(position);
            routes = cell(1, total_travelers);
            total_cost = 0;

            % 分配城市到旅行商
            traveler_allocation = zeros(1, num_cities);
            for city_idx = 1:num_cities
                traveler_id = min(floor(position(city_idx)) + 1, total_travelers);
                traveler_allocation(city_idx) = traveler_id;
            end

            % 构造各旅行商路径
            for traveler_idx = 1:total_travelers
                city_indices = find(traveler_allocation == traveler_idx);
                if isempty(city_indices)
                    routes{traveler_idx} = [];
                    continue;
                end

                % 获取小数部分排序
                decimals = position(city_indices) - floor(position(city_indices));
                [~, order] = sort(decimals, 'descend');
                sorted_cities = city_indices(order) + num_depots; % 转换为节点编号

                % 添加仓库节点
                depot_id = depot_assignment(traveler_idx);
                route = [depot_id; sorted_cities(:); depot_id];

                % 2-opt优化
                optimized_route = PathUtilities.two_opt(route, distance_matrix);

                % 计算路径成本
                route_cost = PathUtilities.calculate_route_cost(optimized_route, distance_matrix);
                total_cost = total_cost + route_cost;
                routes{traveler_idx} = optimized_route;
            end
        end

    end
end