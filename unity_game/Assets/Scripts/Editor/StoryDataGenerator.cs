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
            // 1장 서울: 집과 골목
            Clue("mom_handkerchief", "엄마의 흰 손수건", 1, true,
                "골목 담벼락 아래 떨어져 있던 손수건. 모서리에 엄마 이름 '순자'가 수놓아져 있다. 엄마도 이 길로 지나갔다.");
            Clue("neighbor_testimony", "옆집 할머니의 이야기", 1, true,
                "\"네 엄마? 너 찾는다고 한강 쪽으로 뛰어가더라. 다리 건너면 기다린다고 했어.\"");
            Clue("family_photo", "가족사진", 1, false,
                "작년 봄에 찍은 가족사진. 엄마의 얼굴을 사람들에게 보여주며 물어볼 수 있다.");

            // 2장 한강: 끊어진 다리와 나룻배
            Clue("torn_letter", "찢어진 편지 조각", 2, true,
                "엄마 글씨다. \"...부산 외삼촌 댁으로... 꼭 살아서...\" 나머지는 찢어져 읽을 수 없다.");
            Clue("boatman_testimony", "뱃사공의 증언", 2, false,
                "\"사진 속 이 아주머니, 어제 내 배로 건넜지. 남쪽 가는 기차를 탄다고 하더라.\"");

            // 3장 피난 열차
            Clue("refugee_list", "피난민 명부", 3, true,
                "열차 칸 명부에 '김순자 — 부산행'이라고 적혀 있다. 엄마는 부산으로 갔다!");
            Clue("rice_ball", "주먹밥 한 덩이", 3, false,
                "열차에서 만난 아주머니가 나눠 준 주먹밥. \"힘내라, 꼭 엄마 만날 거야.\"");

            // 4장 부산 국제시장
            Clue("missing_notice", "'사람 찾습니다' 벽보", 4, true,
                "시장 벽에 빼곡한 쪽지들 사이, 엄마 글씨: \"우리 아이를 찾습니다. 매일 해질녘 영도다리에서 기다립니다. — 순자\"");

            // ── 대화 ───────────────────────────────────────────────
            Dialogue("Dlg_Intro",
                ("나", "1950년 6월 28일, 새벽. 멀리서 포성이 울렸다."),
                ("나", "피난 가는 사람들에 떠밀리다가... 엄마 손을 놓쳐 버렸다."),
                ("나", "엄마를 찾아야 해. 엄마가 남긴 흔적을 따라가자."));

            Dialogue("Dlg_Neighbor",
                ("옆집 할머니", "아이고, 너 여기 있었구나!"),
                ("옆집 할머니", "네 엄마가 너 찾는다고 한강 쪽으로 뛰어가더라."),
                ("옆집 할머니", "다리 건너면 기다린다고 했어. 어서 가 봐라."));

            Dialogue("Dlg_Boatman",
                ("뱃사공", "다리는 끊어졌어. 건너려면 내 배를 타야 해."),
                ("뱃사공", "사람을 찾는다고? 얼굴을 알아야 도와주지."));

            Dialogue("Dlg_Boatman_WithPhoto",
                ("나", "이 사진 속 사람, 우리 엄마예요. 혹시 보셨어요?"),
                ("뱃사공", "가만있자... 어제 내 배로 건넌 아주머니구먼!"),
                ("뱃사공", "남쪽 가는 기차를 탄다고 하더라. 너도 어서 가거라."));

            Dialogue("Dlg_Reunion",
                ("나", "해가 지는 영도다리. 수많은 사람들 사이로 낯익은 흰 저고리가 보였다."),
                ("나", "...엄마?"),
                ("엄마", "...! 우리 아가! 정말 너니?"),
                ("엄마", "살아 있어 줘서 고맙다... 고맙다..."),
                ("나", "엄마가 남긴 흔적들이 나를 여기까지 데려왔다."));

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
