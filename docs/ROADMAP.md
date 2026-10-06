# 路线图 / Roadmap

以下为计划顺序，不是当前 SDK 已提供的功能。版本与发布时间尚未承诺。

| 顺序 | 功能 | Planned feature | 状态 |
|---:|---|---|---|
| 1 | 瞳孔大小调节 | Pupil size adjustment | 计划 / Planned |
| 2 | 额头宽窄调节 | Forehead width adjustment | 计划 / Planned |
| 3 | 美瞳佩戴 | Cosmetic contact lenses | 计划 / Planned |
| 4 | 墨镜佩戴 | Virtual sunglasses | 计划 / Planned |
| 5 | 法令纹变淡 | Nasolabial fold reduction | 计划 / Planned |
| 6 | 牙齿美白 | Teeth whitening | 计划 / Planned |
| 7 | 黑眼圈调节 | Dark circle adjustment | 计划 / Planned |
| 8 | 发际线调节 | Hairline adjustment | 计划 / Planned |
| 9 | 发量调节 | Hair volume adjustment | 计划 / Planned |

并行完善的方向：真人动态虚化与遮挡稳定性、头发和脸型变形边缘、口红与眉毛范围、CPU 后处理迁移到 GPU/NPU、芯片级执行策略、长时间温控与 FPS、低端/高端机分档及 Android/iOS Demo 一致性。

Ongoing improvements cover temporal matting and occlusion, hair/face deformation boundaries, makeup regions, accelerator migration, chipset-specific execution, sustained thermal/FPS testing, device tiers and demo parity.

验收应包含真人转头、张嘴、头发移动、不同肤色与光照、效果强度变化，以及指定设备的持续运行。静态照片、短时峰值或“选择了某 delegate”的日志均不能替代完整效果和性能验收。
