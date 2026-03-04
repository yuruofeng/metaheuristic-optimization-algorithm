classdef Visualization
    % VISUALIZATION 可视化工具类
    % 包含路径可视化、收敛曲线绘制等静态方法

    methods (Static)

        function update_visualization(fig_handle, locations, best_routes, depot_assignment, iteration, convergence)
            % UPDATE_VISUALIZATION 更新实时可视化
            % 输入:
            %   fig_handle - 图形句柄
            %   locations - 所有节点坐标矩阵
            %   best_routes - 最优路径元胞数组
            %   depot_assignment - 旅行商到仓库的分配向量
            %   iteration - 当前迭代次数
            %   convergence - 收敛历史向量

            figure(fig_handle);
            colors = lines(max(depot_assignment));

            % 更新路径子图
            subplot(1, 2, 1);
            cla;
            hold on;

            % 绘制基础设施
            num_depots = max(depot_assignment);
            plot(locations(1:num_depots, 1), locations(1:num_depots, 2), ...
                'ks', 'MarkerSize', 12, 'LineWidth', 2);
            plot(locations(num_depots+1:end, 1), locations(num_depots+1:end, 2), ...
                'bo', 'MarkerSize', 8);

            % 绘制所有路径
            for traveler_idx = 1:length(best_routes)
                if ~isempty(best_routes{traveler_idx})
                    depot_id = depot_assignment(traveler_idx);
                    route = best_routes{traveler_idx};
                    plot(locations(route, 1), locations(route, 2), ...
                        'Color', colors(depot_id, :), 'LineWidth', 1.5);
                    plot(locations(route(1), 1), locations(route(1), 2), ...
                        '^', 'Color', colors(depot_id, :), 'MarkerSize', 8);
                end
            end
            title(sprintf('迭代: %d  当前最优: %.2f', iteration, convergence(iteration)));

            % 更新收敛曲线
            subplot(1, 2, 2);
            if iteration == 1
                plot(convergence(1:iteration), 'b-', 'LineWidth', 1.5);
            else
                h = findobj(gca, 'Type', 'line');
                set(h, 'XData', 1:iteration, 'YData', convergence(1:iteration));
            end
            drawnow;
        end

        function draw_final_routes(locations, best_routes, depot_assignment)
            % DRAW_FINAL_ROUTES 绘制最终路径规划结果
            % 输入:
            %   locations - 所有节点坐标矩阵
            %   best_routes - 最优路径元胞数组
            %   depot_assignment - 旅行商到仓库的分配向量

            figure('Name', '最终路径规划', 'Position', [200, 200, 800, 600]);
            colors = lines(max(depot_assignment));
            hold on;

            % 绘制基础设施
            num_depots = max(depot_assignment);
            plot(locations(1:num_depots, 1), locations(1:num_depots, 2), ...
                'ks', 'MarkerSize', 12, 'LineWidth', 2, 'MarkerFaceColor', 'k');
            plot(locations(num_depots+1:end, 1), locations(num_depots+1:end, 2), ...
                'bo', 'MarkerSize', 8, 'LineWidth', 1.5);

            % 绘制路径（添加空值检查）
            for traveler_idx = 1:length(best_routes)
                if ~isempty(best_routes{traveler_idx}) && iscell(best_routes)
                    depot_id = depot_assignment(traveler_idx);
                    route = best_routes{traveler_idx};
                    plot(locations(route, 1), locations(route, 2), ...
                        'Color', colors(depot_id, :), 'LineWidth', 2);
                    text(locations(route(1), 1), locations(route(1), 2), ...
                        sprintf(' T%d', traveler_idx), 'Color', colors(depot_id, :), ...
                        'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            % 添加图例
            legend_str = arrayfun(@(d) sprintf('仓库%d', d), unique(depot_assignment), 'UniformOutput', false);
            h = gobjects(1, length(legend_str));
            valid_count = 1;
            for d = unique(depot_assignment)
                h(valid_count) = plot(nan, nan, '-', 'Color', colors(d, :), 'LineWidth', 2);
                valid_count = valid_count + 1;
            end
            legend(h(1:valid_count-1), legend_str, 'Location', 'best');

            % 计算总成本
            if ~isempty(best_routes) && iscell(best_routes)
                total_cost = 0;
                for traveler_idx = 1:length(best_routes)
                    if ~isempty(best_routes{traveler_idx})
                        route = best_routes{traveler_idx};
                        for i = 1:length(route)-1
                            total_cost = total_cost + norm(locations(route(i), :) - locations(route(i+1), :));
                        end
                    end
                end
                title(sprintf('最终路径规划 (总成本: %.2f)', total_cost));
            else
                title('最终路径规划');
            end

            grid on;
            hold off;
        end

        function plot_convergence(convergence_history, algorithm_names)
            % PLOT_CONVERGENCE 绘制算法收敛曲线对比
            % 输入:
            %   convergence_history - 收敛历史元胞数组，每个元素是一个算法的收敛历史向量
            %   algorithm_names - 算法名称元胞数组

            figure('Name', '算法收敛曲线对比', 'Position', [100, 100, 1200, 500]);
            hold on;

            colors = lines(length(convergence_history));
            for i = 1:length(convergence_history)
                plot(convergence_history{i}, 'LineWidth', 2, 'Color', colors(i, :));
            end

            legend(algorithm_names, 'Location', 'northeast');
            title('算法收敛曲线对比');
            xlabel('迭代次数');
            ylabel('总路径长度');
            grid on;
            set(gca, 'YScale', 'log');
            hold off;
        end

        function plot_algorithm_comparison(results, algorithm_names)
            % PLOT_ALGORITHM_COMPARISON 绘制算法结果对比图
            % 输入:
            %   results - 结果结构体数组，每个元素包含：
            %       best_cost - 最优成本
            %       best_routes - 最优路径
            %       convergence - 收敛历史
            %   algorithm_names - 算法名称元胞数组

            num_algorithms = length(results);
            figure('Name', '路径规划对比', 'Position', [100, 100, 1400, 1000]);

            for i = 1:num_algorithms
                subplot(2, ceil(num_algorithms/2), i);
                Visualization.plot_single_solution(results(i).best_routes, ...
                    results(i).problem, algorithm_names{i});
            end
        end

        function plot_single_solution(routes, problem, algorithm_name)
            % PLOT_SINGLE_SOLUTION 绘制单个算法的解决方案
            % 输入:
            %   routes - 路径元胞数组
            %   problem - 问题结构体
            %   algorithm_name - 算法名称

            hold on;

            % 提取坐标
            if isfield(problem, 'locations')
                locations = problem.locations;
                num_depots = problem.num_depots;
            else
                locations = [problem.depot_coords; problem.city_coords];
                num_depots = size(problem.depot_coords, 1);
            end

            % 绘制基础设施
            plot(locations(1:num_depots, 1), locations(1:num_depots, 2), ...
                'ks', 'MarkerSize', 10, 'LineWidth', 3);
            plot(locations(num_depots+1:end, 1), locations(num_depots+1:end, 2), ...
                'bo', 'MarkerSize', 8);

            % 绘制路径
            if iscell(routes)
                colors = lines(num_depots);
                for traveler_idx = 1:length(routes)
                    if ~isempty(routes{traveler_idx})
                        route = routes{traveler_idx};
                        % 确定仓库ID（路径的第一个节点）
                        depot_id = route(1);
                        plot(locations(route, 1), locations(route, 2), ...
                            'Color', colors(depot_id, :), 'LineWidth', 1.5);
                    end
                end
            end

            title([algorithm_name, ' 优化结果']);
            xlabel('X坐标');
            ylabel('Y坐标');
            grid on;
            hold off;
        end

    end
end