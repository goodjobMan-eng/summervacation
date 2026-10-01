using System.IO;
using UnityEditor;
using UnityEngine;

namespace Refugee1950.EditorTools
{
    /// <summary>
    /// 메뉴 [피난길 → 기본 스토리 데이터 만들기] 를 누르면
    /// Assets/StoryData 폴더에 기본 단서와 대화 에셋을 만들어 준다. (이미 있으면 덮어쓰지 않는다)
    /// </summary>
    public static class StoryDataGenerator
    {
        const string Root = "Assets/StoryData";

        [MenuItem("피난길/기본 스토리 데이터 만들기")]
        public static void Generate()
        {
            Directory.CreateDirectory(Root + "/Clues");
            Directory.CreateDirectory(Root + "/Dialogues");

            // ── 단서 ───────────────────────────────────────────────
            // 1장 1950년 12월, 장단역: 멈춰 선 피난 열차
            Clue("mom_handkerchief", "엄마의 흰 손수건", 1, true,
                "눈 덮인 승강장에 떨어져 있던 손수건. 모서리에 엄마 이름 '순자'가 수놓아져 있다. 엄마도 이 역에 있었다.");
            Clue("stationmaster_testimony", "역무원의 이야기", 1, true,
                "\"기차는 여기서 더는 못 간다. 사람들은 다 얼어붙은 임진강을 걸어서 건너 문산 쪽으로 갔어. 흰 손수건 찾던 아주머니도.\"");
            Clue("family_photo", "가족사진", 1, false,
                "작년 봄에 찍은 가족사진. 엄마의 얼굴을 사람들에게 보여주며 물어볼 수 있다.");

            // 2장 1953년 8월, 문산 자유의 다리
            Clue("refugee_list", "문산 피난민촌 명부", 2, true,
                "천막촌 명부에 '김순자 — 장단군 출신, 아이를 찾는 중'이라고 적혀 있다. 엄마는 살아 있다!");
            Clue("soldier_testimony", "헌병 아저씨의 증언", 2, false,
                "\"사진 속 이 아주머니, 포로 교환이 시작된 뒤로 매일 다리 앞에 와서 사람들 얼굴을 살피던 분이야.\"");
            Clue("missing_notice", "다리 난간의 쪽지", 2, true,
                "자유의 다리 앞 철조망에 묶인 수많은 쪽지 사이, 엄마 글씨: \"장단역에서 헤어진 우리 아이를 찾습니다. 매일 해질녘 임진강 가에서 기다립니다. — 순자\"");

            // ── 대화 ───────────────────────────────────────────────
            Dialogue("Dlg_Intro_Jangdan",
                ("나", "1950년 12월, 장단역. 북쪽에서 중공군이 내려온다는 소식에 역은 피난민으로 가득했다."),
                ("나", "남쪽으로 가던 기차가 멈춰 서고, 사람들이 한꺼번에 몰려나오다가... 엄마 손을 놓쳐 버렸다."),
                ("나", "엄마를 찾아야 해. 엄마가 남긴 흔적을 따라가자."));

            Dialogue("Dlg_Stationmaster",
                ("역무원", "얘야, 여기 있으면 안 된다. 기차는 더 못 가."),
                ("역무원", "흰 손수건 찾던 아주머니? 아이 이름을 부르면서 임진강 쪽으로 가더라."),
                ("역무원", "강이 꽁꽁 얼었으니 걸어서 건널 수 있다. 문산까지 가거라."));

            Dialogue("Dlg_Intro_FreedomBridge",
                ("나", "그로부터 3년. 1953년 7월, 마침내 휴전이 되었다."),
                ("나", "8월, 문산. 임진강 위 나무다리로 포로들이 \"자유 만세!\"를 외치며 돌아오고 있다."),
                ("나", "사람들은 이 다리를 '자유의 다리'라고 불렀다. 엄마도 여기 어딘가에서 누군가를 기다리고 있을지 몰라."));

            Dialogue("Dlg_Soldier",
                ("헌병", "다리 쪽으로는 더 못 간다. 귀환 용사들이 지나가는 중이야."),
                ("헌병", "사람을 찾는다고? 여기 오는 사람들 다 누군가를 찾지. 얼굴을 알아야 도와주지."));

            Dialogue("Dlg_Soldier_WithPhoto",
                ("나", "이 사진 속 사람, 우리 엄마예요. 혹시 보셨어요?"),
                ("헌병", "가만있자... 매일 다리 앞에 와서 사람들 얼굴 살피던 아주머니구먼!"),
                ("헌병", "해 질 무렵이면 늘 강가로 가더라. 어서 가 봐라."));

            Dialogue("Dlg_Reunion",
                ("나", "해가 지는 임진강 가. 강 건너 고향 쪽을 바라보는 낯익은 흰 저고리가 보였다."),
                ("나", "...엄마?"),
                ("엄마", "...! 우리 아가! 정말 너니?"),
                ("엄마", "장단역에서 놓친 손을... 3년 동안 하루도 잊은 적이 없다..."),
                ("나", "훗날 이 강가에는 임진각이 세워졌다."),
                ("나", "장단역에 멈춰 섰던 기관차도, 고향에 돌아가지 못한 사람들이 북녘을 향해 절하는 망배단도 그곳에 있다."),
                ("나", "우리는 함께였지만, 아직 그곳에서 가족을 기다리는 사람들이 있다."));

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log($"[피난길] 기본 스토리 데이터를 {Root} 에 만들었습니다. GameManager의 All Clues에 Clues 폴더의 단서들을 넣어 주세요.");
        }

        static void Clue(string id, string title, int chapter, bool isKey, string description)
        {
            string path = $"{Root}/Clues/Clue_{id}.asset";
            if (AssetDatabase.LoadAssetAtPath<ClueData>(path) != null) return;

            var clue = ScriptableObject.CreateInstance<ClueData>();
            clue.id = id;
            clue.title = title;
            clue.chapter = chapter;
            clue.isKeyClue = isKey;
            clue.description = description;
            AssetDatabase.CreateAsset(clue, path);
        }

        static void Dialogue(string name, params (string speaker, string text)[] lines)
        {
            string path = $"{Root}/Dialogues/{name}.asset";
            if (AssetDatabase.LoadAssetAtPath<DialogueData>(path) != null) return;

            var data = ScriptableObject.CreateInstance<DialogueData>();
            data.lines = new DialogueLine[lines.Length];
            for (int i = 0; i < lines.Length; i++)
                data.lines[i] = new DialogueLine { speaker = lines[i].speaker, text = lines[i].text };
            AssetDatabase.CreateAsset(data, path);
        }
    }
}
