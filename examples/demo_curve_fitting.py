#!/usr/bin/env python
# coding: utf-8
# @author: Zhijian Qiao
# @email: zqiaoac@connect.ust.hk

import numpy as np
import open3d as o3d
import os
import sys
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../"))
sys.path.append(ROOT_DIR)
from misc.curve.bspline_approx import CubicBSplineApproximator, BSplineGridApproximator
from misc.curve.catmull_rom import CatmullRomSplineList, CentripetalCatmullRomSpline
import matplotlib
matplotlib.use('Agg')  # 使用非交互式后端，避免在无GUI环境中出错
import matplotlib.pyplot as plt

def main():
    lane_pcd= o3d.io.read_point_cloud(os.path.join(ROOT_DIR, "examples/data/lane.pcd"))
    # 采用Open3D中的方法voxel_down_sample对数据进行降采样
    # 车道线宽度一般在0.1m~0.2m之间，采样体素大小设置为0.1m，代码中的0.01适合于更精细的点云
    lane_pcd = lane_pcd.voxel_down_sample(voxel_size=0.01)
    lane_points = np.asarray(lane_pcd.points)
    # 人工预先选取的控制点
    lane_key_points = np.asarray(o3d.io.read_point_cloud(os.path.join(ROOT_DIR, "examples/data/lane_selected.pcd")).points)

    # bspline approximation
    bspline_results = bspline_approximation(lane_points)

    # bspline grid approximation
    print("BSpline approximation using grid")
    b_grid_approx = BSplineGridApproximator(resolution=5)
    fitted_points = b_grid_approx.global_optimize(lane_points)
    b_grid_approx.plot_result(lane_points, fitted_points)

    # catmull-rom spline interpolation and combined plot
    catmull_rom_interpolate(lane_points, lane_key_points, bspline_results)

    # ctrlpts_sphere = pointcloud_to_spheres(lane_key_points, sphere_size=0.5, color=[0.7, 0.1, 0.1])
    # o3d.visualization.draw_geometries([ctrlpts_sphere, lane_pcd])

def catmull_rom_interpolate(lane_points, lane_key_points, bspline_results=None):
    spline = CatmullRomSplineList(lane_key_points, tau=0.5)
    points_cr_0_5 = spline.get_points(20)
    # catmull-rom (seems to be sharper than centripetal)
    spline = CatmullRomSplineList(lane_key_points, tau=0.1)
    points_cr_0_1 = spline.get_points(20)

    spline = CentripetalCatmullRomSpline(lane_key_points, alpha=0.5)
    points_ccr_0_5 = spline.get_points(20)

    plt.figure(figsize=(20, 12))
    plt.plot(lane_points[:, 0], lane_points[:, 1], 'y.', markersize=2, label="lane points", alpha=0.5)
    
    # Plot Catmull-Rom results
    plt.plot(points_cr_0_5[:, 0], points_cr_0_5[:, 1], 'b.-', linewidth=2, markersize=3, label="catmull-rom tau=0.5")
    plt.plot(points_cr_0_1[:, 0], points_cr_0_1[:, 1], 'g.-', linewidth=2, markersize=3, label="catmull-rom tau=0.1")
    plt.plot(points_ccr_0_5[:, 0], points_ccr_0_5[:, 1], 'c.-', linewidth=2, markersize=3, label="centripetal catmull-rom alpha=0.5")
    
    # Plot BSpline results if available
    if bspline_results is not None:
        for method_name, points in bspline_results.items():
            if method_name == "chord_length":
                plt.plot(points[:, 0], points[:, 1], 'r.-', linewidth=2, markersize=3, label=f"B-Spline {method_name}")
            elif method_name == "xyz_norm":
                plt.plot(points[:, 0], points[:, 1], 'm.-', linewidth=2, markersize=3, label=f"B-Spline {method_name}")
            elif method_name == "iterative":
                plt.plot(points[:, 0], points[:, 1], 'k.-', linewidth=2, markersize=3, label=f"B-Spline {method_name}")
    
    # Plot the control points
    plt.plot(lane_key_points[:, 0], lane_key_points[:, 1], 'o', color='orange', markersize=8, label="control points")
    plt.title('Curve Fitting Comparison: B-Spline vs Catmull-Rom', fontsize=16)
    plt.xlabel('X', fontsize=14)
    plt.ylabel('Y', fontsize=14)
    plt.legend(prop={'size': 12}, loc='best')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(ROOT_DIR, "outputs/lane_fit_comparison.png"), dpi=150)
    print("Saved comparison plot to outputs/lane_fit_comparison.png")


def bspline_approximation(lane_points):
    # bspline approximation using the lane points
    print("BSpline approximation using the lane points")
    approximator = CubicBSplineApproximator(max_iter = 20, res_delta_tld = 5e-2)
    
    results = {}
    
    print("knots association using chord_length method")
    bspline3 = approximator.approximate(lane_points, method="chord_length")
    results["chord_length"] = bspline3.get_points_final(num=100)
    
    print("knots association using xyz_norm method")
    bspline3 = approximator.approximate(lane_points, method="xyz_norm")
    results["xyz_norm"] = bspline3.get_points_final(num=100)
    
    print("knots association using iterative method")
    bspline3 = approximator.approximate(lane_points, method="iterative")
    results["iterative"] = bspline3.get_points_final(num=100)
    
    return results

if __name__ == '__main__':

    main()