# 计算TR所需BOM
#

import math

def main():
    lane_spacing = 17.
    c_cart_width = 28.9
    h_cart_width = 39.9
    extrusion_extra_len = 30.
    belt_base_len = 199.1
    belt_safety = 30.
    chain_base_lens = {
        15.:    120,
        16.7:   124,
        20.:    130
    }
    m3x8_base_count = 25
    m3x8_safety = 10
    m3x8_rail_pitch = 40.
    m3x8_rail_end = 4.5
    m3_t_nut_base_count = 3

    # get lane count
    lane_count = int(input("需要接入的耗材数量："))

    # calculate lane_span and minimum rail lengths
    lane_span = get_lane_span(lane_count, lane_spacing)
    c_rail_len = lane_span + c_cart_width
    h_rail_len = lane_span + h_cart_width

    # display required rail lengths
    print("\nC型滑块最小轨道长度：{}".format(c_rail_len))
    print("H型滑块最小轨道长度：{}".format(h_rail_len))

    # get rail cart type and corresponding minimum rail length
    cart_type = input("\n准备使用的线轨滑块类型(请输入c/h)：").lower()
    min_rail_len = c_rail_len if cart_type == "c" else h_rail_len

    # get rail length
    rail_len_str = input("准备使用的线轨长度 "
                        "(默认使用最小值)：")
    rail_len = max(float(rail_len_str), min_rail_len) if rail_len_str \
        else min_rail_len

    # check if user wants to increase the number of lanes
    cart_width = c_cart_width if cart_type == "c" else h_cart_width
    max_lane_count = math.floor((rail_len - cart_width) / lane_spacing) + 1
    if max_lane_count > lane_count:
        change_lane_count = input("此线轨长度允许最多{}"
                                  "路耗材。需要将耗材接入数量从{}增加到{}吗？"
                                  "(请输入y/n): ".format(max_lane_count, lane_count, 
                                                   max_lane_count)).lower()
        if change_lane_count == "y":
            lane_count = max_lane_count
            lane_span = get_lane_span(lane_count, lane_spacing)

    # get cable chain pitch
    print("\n拖链节距选项："
          "\n\t15\t(e.g. JFLO J10Q.1.10B)"
          "\n\t16.7\t(e.g. JFLO J10Q.1.10W)"
          "\n\t20\t(e.g. IGUS E2-10-10-028-0)\n")
    chain_pitch = 0.
    while(not chain_pitch in chain_base_lens):
        chain_pitch = float(input("输入所选拖链的节距："))

    print()

    # lane count
    print("耗材接入数量：{}".format(lane_count))

    # rail
    print("线轨滑块类型：{}".format("c" if min_rail_len == c_rail_len \
        else "h"))
    print("线轨长度：{}mm".format(rail_len))

    # extrusion
    extrusion_len = rail_len + extrusion_extra_len
    print("最小挤出长度：{}mm".format(extrusion_len))

    # belt
    belt_len = belt_base_len + lane_span * 2
    belt_len_rec = math.ceil(belt_len + belt_safety)
    print("皮带长度：建议{}mm(预估需要{}mm))".format(belt_len_rec, 
                                                                belt_len))

    # cable chain
    chain_length = lane_span / 2 + chain_base_lens[chain_pitch]
    chain_link_count = math.ceil(chain_length / chain_pitch)
    print("预估拖链长度：{}mm".format(chain_length))
    print("需要使用拖链节数(不包括两侧固定节点)：{}" \
        .format(chain_link_count))

    # M3x8 screws and M3 T-nuts
    rail_screw_count = math.floor((rail_len - 2 * m3x8_rail_end) \
        / m3x8_rail_pitch) + 1
    m3x8_count = m3x8_base_count + lane_count + rail_screw_count
    m3x8_count_rec = m3x8_count + m3x8_safety
    t_nut_count = rail_screw_count + m3_t_nut_base_count
    print("M3x8mm内六角螺丝数量：建议{} "
        "(预估需要{})".format(m3x8_count_rec, m3x8_count))
    print("M3弹珠螺母数量：{}".format(t_nut_count))

def get_lane_span(lane_count, lane_spacing):
    return (lane_count - 1) * lane_spacing

if __name__ == "__main__":
    main()
